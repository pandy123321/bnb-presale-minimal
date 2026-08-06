// PANGU2 Chain Worker — Database Layer
// Schema v3: hash-scoped reorg, maintenance lease, checkpoint no-overwrite.

import { Pool, type PoolClient } from "pg";

export interface RawEventRow {
  chain_id: number; contract_address: string; event_name: string | null;
  transaction_hash: string; log_index: number; block_number: number;
  block_hash: string; transaction_index: number | null; block_timestamp: string;
  decoded_data: Record<string, unknown>; topics: string[]; raw_data?: string | null; status: string;
}

export interface CursorRow {
  chain_id: number; stream: string; last_scanned_block: number;
  last_scanned_block_hash: string | null; status: string;
  lease_holder: string | null; lease_expires_at: Date | null; lease_generation: number;
  maintenance_lease_active: boolean;
}

let pool: Pool | null = null;

export function getPool(): Pool {
  if (!pool) pool = new Pool({
    host: process.env.DATABASE_HOST ?? "localhost",
    port: parseInt(process.env.DATABASE_PORT ?? "5432"),
    database: process.env.DATABASE_NAME ?? "bnb_presale",
    user: process.env.DATABASE_USER ?? "bnb",
    password: process.env.DATABASE_PASSWORD ?? "bnb_dev_pass",
    max: 5,
  });
  return pool;
}

export async function closePool(): Promise<void> { if (pool) { await pool.end(); pool = null; } }

// ── Schema Version ──────────────────────────

const SCHEMA_VERSION = 3;
export async function verifySchemaVersion(): Promise<void> {
  const { rows } = await getPool().query(`SELECT COALESCE(schema_version, 0) AS v FROM chain_cursors_settings LIMIT 1`);
  if (rows.length === 0 || parseInt(rows[0].v as string) < SCHEMA_VERSION) {
    throw new Error(`Schema version < ${SCHEMA_VERSION}. Run migration 003 first.`);
  }
}

// ── Block Checkpoints ───────────────────────

export async function insertBlockCheckpoint(
  client: PoolClient, chainId: number, blockNumber: number, blockHash: string,
): Promise<{ conflict: boolean }> {
  const { rows } = await client.query(
    `INSERT INTO chain_block_checkpoints (chain_id, block_number, block_hash, created_at)
     VALUES ($1, $2, $3, NOW()) ON CONFLICT (chain_id, block_number) DO NOTHING RETURNING block_hash`,
    [chainId, blockNumber, blockHash],
  );
  if (rows.length > 0) return { conflict: false };

  const { rows: ex } = await client.query(
    `SELECT block_hash FROM chain_block_checkpoints WHERE chain_id = $1 AND block_number = $2`,
    [chainId, blockNumber],
  );
  const oldHash = (ex[0].block_hash as string).toLowerCase();
  if (oldHash !== blockHash.toLowerCase()) {
    await client.query(
      `INSERT INTO chain_block_checkpoint_history (chain_id, block_number, old_block_hash, new_block_hash)
       VALUES ($1, $2, $3, $4)`,
      [chainId, blockNumber, oldHash, blockHash],
    );
    await client.query(
      `UPDATE chain_block_checkpoints SET block_hash = $3, created_at = NOW() WHERE chain_id = $1 AND block_number = $2`,
      [chainId, blockNumber, blockHash],
    );
    return { conflict: true };
  }
  return { conflict: false };
}

export async function getBlockCheckpointsInRange(
  client: PoolClient, chainId: number, fromBlock: number, toBlock: number,
): Promise<Array<{ blockNumber: number; storedHash: string }>> {
  const { rows } = await client.query(
    `SELECT block_number, block_hash FROM chain_block_checkpoints
     WHERE chain_id = $1 AND block_number BETWEEN $2 AND $3 ORDER BY block_number`,
    [chainId, fromBlock, toBlock],
  );
  return rows.map(r => ({ blockNumber: parseInt(r.block_number as string), storedHash: (r.block_hash as string).toLowerCase() }));
}

// ── Cursor Operations ────────────────────────

export async function getCursor(client: PoolClient | Pool, chainId: number, stream: string): Promise<CursorRow | null> {
  const { rows } = await client.query(
    `SELECT chain_id, stream, last_scanned_block, last_scanned_block_hash,
            status, lease_holder, lease_expires_at, COALESCE(lease_generation, 0) AS lease_generation,
            COALESCE(maintenance_lease_active, false) AS maintenance_lease_active
     FROM chain_cursors WHERE chain_id = $1 AND stream = $2`, [chainId, stream],
  );
  if (rows.length === 0) return null;
  const r = rows[0];
  return {
    chain_id: parseInt(r.chain_id), stream: r.stream, last_scanned_block: parseInt(r.last_scanned_block),
    last_scanned_block_hash: r.last_scanned_block_hash ?? null, status: r.status,
    lease_holder: r.lease_holder ?? null, lease_expires_at: r.lease_expires_at ?? null,
    lease_generation: parseInt(r.lease_generation ?? "0"), maintenance_lease_active: (r.maintenance_lease_active ?? false),
  };
}

export async function upsertCursor(
  client: PoolClient, chainId: number, stream: string, blockNumber: number, blockHash: string | null,
  status: string, workerId: string, leaseGeneration: number,
): Promise<boolean> {
  const { rowCount } = await client.query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, last_scanned_block_hash, status, last_run_completed_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     ON CONFLICT (chain_id, stream)
     DO UPDATE SET last_scanned_block = $3, last_scanned_block_hash = $4, status = $5, last_run_completed_at = NOW(), updated_at = NOW()
     WHERE chain_cursors.lease_generation = $6 AND chain_cursors.lease_holder = $7 AND chain_cursors.lease_expires_at > NOW() AND NOT chain_cursors.maintenance_lease_active`,
    [chainId, stream, blockNumber, blockHash, status, leaseGeneration, workerId],
  );
  return (rowCount ?? 0) > 0;
}

// ── Lease ────────────────────────────────────

export async function acquireLease(chainId: number, stream: string, workerId: string, ttlSeconds: number): Promise<{ leased: boolean; leaseGeneration: number }> {
  await getPool().query(`INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_generation) VALUES ($1, $2, 0, 'PENDING', 0) ON CONFLICT DO NOTHING`, [chainId, stream]);
  const { rowCount, rows } = await getPool().query(
    `UPDATE chain_cursors SET lease_holder = $3, lease_expires_at = NOW() + ($4 || ' seconds')::INTERVAL, lease_generation = lease_generation + 1
     WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW()) RETURNING lease_generation`,
    [chainId, stream, workerId, ttlSeconds],
  );
  return (rowCount ?? 0) > 0 ? { leased: true, leaseGeneration: parseInt(rows[0].lease_generation as string) } : { leased: false, leaseGeneration: 0 };
}

export async function releaseLease(chainId: number, stream: string, workerId: string, leaseGeneration: number): Promise<void> {
  await getPool().query(`UPDATE chain_cursors SET lease_holder = NULL, lease_expires_at = NULL WHERE chain_id = $1 AND stream = $2 AND lease_holder = $3 AND lease_generation = $4`, [chainId, stream, workerId, leaseGeneration]);
}

// ── Maintenance Lease (global reorg fence) ───

export async function acquireMaintenanceLease(chainId: number, workerId: string, ttlSeconds: number): Promise<{ leased: boolean; leaseGeneration: number }> {
  await getPool().query(`INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_generation) VALUES ($1, 'REORG_GLOBAL', 0, 'HEALTHY', 0) ON CONFLICT DO NOTHING`, [chainId]);
  const { rowCount, rows } = await getPool().query(
    `UPDATE chain_cursors SET maintenance_lease_active = true, lease_holder = $2, lease_expires_at = NOW() + ($3 || ' seconds')::INTERVAL, lease_generation = lease_generation + 1
     WHERE chain_id = $1 AND stream = 'REORG_GLOBAL' AND (lease_holder IS NULL OR lease_expires_at < NOW()) RETURNING lease_generation`,
    [chainId, workerId, ttlSeconds],
  );
  return (rowCount ?? 0) > 0 ? { leased: true, leaseGeneration: parseInt(rows[0].lease_generation as string) } : { leased: false, leaseGeneration: 0 };
}

export async function releaseMaintenanceLease(chainId: number, workerId: string, leaseGeneration: number): Promise<void> {
  await getPool().query(`UPDATE chain_cursors SET maintenance_lease_active = false, lease_holder = NULL, lease_expires_at = NULL WHERE chain_id = $1 AND stream = 'REORG_GLOBAL' AND lease_holder = $2 AND lease_generation = $3`, [chainId, workerId, leaseGeneration]);
}

export async function validateMaintenanceLease(client: PoolClient, chainId: number, workerId: string, leaseGeneration: number): Promise<boolean> {
  const { rows } = await client.query(`SELECT lease_holder, lease_generation, lease_expires_at, maintenance_lease_active FROM chain_cursors WHERE chain_id = $1 AND stream = 'REORG_GLOBAL' FOR UPDATE`, [chainId]);
  if (rows.length === 0) return false;
  const r = rows[0];
  return r.lease_holder === workerId && parseInt(r.lease_generation as string) === leaseGeneration && (r.lease_expires_at as Date) > new Date() && r.maintenance_lease_active === true;
}

export async function maintenanceLeaseActive(client: PoolClient, chainId: number): Promise<boolean> {
  const { rows } = await client.query(`SELECT maintenance_lease_active FROM chain_cursors WHERE chain_id = $1 AND stream = 'REORG_GLOBAL'`, [chainId]);
  return rows.length > 0 && rows[0].maintenance_lease_active === true;
}

// ── Raw Events ───────────────────────────────

export async function insertRawEvents(client: PoolClient, events: RawEventRow[]): Promise<number> {
  if (events.length === 0) return 0;
  const values: unknown[] = []; const phs: string[] = []; let idx = 1;
  for (const ev of events) {
    phs.push(`($${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++}::jsonb,$${idx++}::jsonb,$${idx++},'PENDING_CONFIRMATION')`);
    values.push(ev.chain_id, ev.contract_address, ev.event_name ?? "unknown", ev.transaction_hash, ev.log_index, ev.block_number, ev.block_hash, ev.transaction_index ?? null, ev.block_timestamp, JSON.stringify(ev.decoded_data), JSON.stringify(ev.topics), ev.raw_data ?? null);
  }
  const r = await client.query(`INSERT INTO chain_raw_events (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, raw_data, status) VALUES ${phs.join(",")} ON CONFLICT (chain_id, transaction_hash, log_index, block_hash) DO NOTHING`, values);
  return r.rowCount ?? 0;
}

// ── Hash-scoped Reorg ────────────────────────

export async function markBlockReorgedHashScoped(client: PoolClient, chainId: number, blockNumber: number, staleHash: string): Promise<number> {
  const { rowCount } = await client.query(`UPDATE chain_raw_events SET status = 'REORGED', reorged_at = NOW(), updated_at = NOW() WHERE chain_id = $1 AND block_number = $2 AND block_hash = $3 AND status != 'REORGED'`, [chainId, blockNumber, staleHash]);
  return rowCount ?? 0;
}

export async function markPendingsReorged(client: PoolClient, chainId: number, blockNumber: number, staleHash: string): Promise<number> {
  const { rowCount } = await client.query(`UPDATE chain_raw_events SET status = 'REORGED', reorged_at = NOW(), updated_at = NOW() WHERE chain_id = $1 AND block_number = $2 AND block_hash = $3 AND status = 'PENDING_CONFIRMATION'`, [chainId, blockNumber, staleHash]);
  return rowCount ?? 0;
}

export async function deleteProjectionsHashScoped(client: PoolClient, chainId: number, blockNumber: number, blockHash: string): Promise<number> {
  const { rowCount } = await client.query(`DELETE FROM transaction_projections WHERE chain_id = $1 AND block_number = $2 AND block_hash = $3`, [chainId, blockNumber, blockHash]);
  return rowCount ?? 0;
}

export async function rewindCursorMaintenance(client: PoolClient, chainId: number, stream: string, rewindTo: number): Promise<boolean> {
  const { rowCount } = await client.query(`UPDATE chain_cursors SET last_scanned_block = $3, status = 'REORG_RECOVERY', updated_at = NOW() WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW())`, [chainId, stream, rewindTo]);
  return (rowCount ?? 0) > 0;
}

// ── Confirmation ─────────────────────────────

export async function confirmEvents(client: PoolClient, chainId: number, blockNumber: number, canonicalHash: string): Promise<number> {
  const { rowCount } = await client.query(`UPDATE chain_raw_events SET status = 'CONFIRMED', confirmed_at = NOW(), updated_at = NOW() WHERE chain_id = $1 AND block_number = $2 AND block_hash = $3 AND status = 'PENDING_CONFIRMATION'`, [chainId, blockNumber, canonicalHash]);
  return rowCount ?? 0;
}

export async function findPendingBlocksToConfirm(client: PoolClient, chainId: number, safeThreshold: number): Promise<Array<{ blockNumber: number; storedHash: string }>> {
  const { rows } = await client.query(`SELECT DISTINCT block_number, block_hash FROM chain_raw_events WHERE chain_id = $1 AND status = 'PENDING_CONFIRMATION' AND block_number <= $2 ORDER BY block_number ASC`, [chainId, safeThreshold]);
  return rows.map(r => ({ blockNumber: parseInt(r.block_number as string), storedHash: (r.block_hash as string).toLowerCase() }));
}

// ── Reorg Detection ──────────────────────────

export async function findReorgedBlocks(client: PoolClient, chainId: number, fromBlock: number, toBlock: number): Promise<Array<{ blockNumber: number; storedHash: string }>> {
  const { rows } = await client.query(`SELECT DISTINCT block_number, block_hash FROM chain_raw_events WHERE chain_id = $1 AND block_number BETWEEN $2 AND $3 AND status IN ('CONFIRMED', 'PENDING_CONFIRMATION') ORDER BY block_number`, [chainId, fromBlock, toBlock]);
  return rows.map(r => ({ blockNumber: parseInt(r.block_number as string), storedHash: (r.block_hash as string).toLowerCase() }));
}

// ── Scanner streams ──────────────────────────

const SCANNER_STREAMS = ["TRADE_EVENTS", "DIVIDEND_EVENTS"];

export async function getAllScannerStreams(client: PoolClient, chainId: number): Promise<Array<{ stream: string; last_scanned_block: number }>> {
  const { rows } = await client.query(`SELECT stream, last_scanned_block FROM chain_cursors WHERE chain_id = $1 AND stream = ANY($2)`, [chainId, SCANNER_STREAMS]);
  return rows.map(r => ({ stream: r.stream as string, last_scanned_block: parseInt(r.last_scanned_block as string) }));
}

export async function checkLeaseValid(client: PoolClient, chainId: number, stream: string, leaseGeneration: number, workerId: string): Promise<boolean> {
  const { rows } = await client.query(`SELECT lease_generation, lease_holder, lease_expires_at FROM chain_cursors WHERE chain_id = $1 AND stream = $2`, [chainId, stream]);
  if (rows.length === 0) return false;
  const r = rows[0];
  return parseInt((r.lease_generation ?? "0") as string) === leaseGeneration && (r.lease_holder as string) === workerId && (r.lease_expires_at as Date) > new Date();
}
