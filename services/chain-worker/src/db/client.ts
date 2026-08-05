// PANGU2 Chain Worker — Database Layer
// PostgreSQL client for raw events, cursors, projections, and outbox writes.

import { Pool, type PoolClient } from "pg";

export interface RawEventRow {
  chain_id: number;
  contract_address: string;
  event_name: string | null;
  transaction_hash: string;
  log_index: number;
  block_number: number;
  block_hash: string;
  transaction_index: number | null;
  block_timestamp: string;
  decoded_data: Record<string, unknown>;
  topics: string[];
  raw_data?: string | null;
  status: string;
}

export interface CursorRow {
  chain_id: number;
  stream: string;
  last_scanned_block: number;
  last_scanned_block_hash: string | null;
  status: string;
  lease_holder: string | null;
  lease_expires_at: Date | null;
  lease_generation: number;
}

let pool: Pool | null = null;

export function getPool(): Pool {
  if (!pool) {
    pool = new Pool({
      host: process.env.DATABASE_HOST ?? "localhost",
      port: parseInt(process.env.DATABASE_PORT ?? "5432"),
      database: process.env.DATABASE_NAME ?? "bnb_presale",
      user: process.env.DATABASE_USER ?? "bnb",
      password: process.env.DATABASE_PASSWORD ?? "bnb_dev_pass",
      max: 5,
    });
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) { await pool.end(); pool = null; }
}

// ── Cursor Operations ────────────────────────

/** Returns full CursorRow or null. Caller reads .last_scanned_block */
export async function getCursor(
  client: PoolClient | Pool,
  chainId: number,
  stream: string,
): Promise<CursorRow | null> {
  const { rows } = await client.query(
    `SELECT chain_id, stream, last_scanned_block, last_scanned_block_hash,
            status, lease_holder, lease_expires_at,
            COALESCE(lease_generation, 0) AS lease_generation
     FROM chain_cursors WHERE chain_id = $1 AND stream = $2`,
    [chainId, stream],
  );
  if (rows.length > 0) {
    return {
      chain_id: parseInt(rows[0].chain_id),
      stream: rows[0].stream,
      last_scanned_block: parseInt(rows[0].last_scanned_block),
      last_scanned_block_hash: rows[0].last_scanned_block_hash ?? null,
      status: rows[0].status,
      lease_holder: rows[0].lease_holder ?? null,
      lease_expires_at: rows[0].lease_expires_at ?? null,
      lease_generation: parseInt(rows[0].lease_generation ?? "0"),
    };
  }
  return null;
}

/** upsertCursor with lease fencing: only the current lease generation may write */
export async function upsertCursor(
  client: PoolClient,
  chainId: number,
  stream: string,
  blockNumber: number,
  blockHash: string | null,
  status: string = "HEALTHY",
  leaseGeneration: number,
): Promise<boolean> {
  const { rowCount } = await client.query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, last_scanned_block_hash, status, last_run_completed_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     ON CONFLICT (chain_id, stream)
     DO UPDATE SET last_scanned_block = $3, last_scanned_block_hash = $4, status = $5, last_run_completed_at = NOW(), updated_at = NOW()
     WHERE chain_cursors.lease_generation = $6`,
    [chainId, stream, blockNumber, blockHash, status, leaseGeneration],
  );
  return (rowCount ?? 0) > 0;
}

// ── Lease (Distributed Lock with fencing token) ──

export async function acquireLease(
  chainId: number,
  stream: string,
  workerId: string,
  ttlSeconds: number,
): Promise<{ leased: boolean; leaseGeneration: number }> {
  // Upsert the cursor row if missing (cold-start)
  await getPool().query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_generation)
     VALUES ($1, $2, 0, 'PENDING', 0)
     ON CONFLICT (chain_id, stream) DO NOTHING`,
    [chainId, stream],
  );

  // Atomically: increment lease_generation + set holder if expired or free
  const { rowCount, rows } = await getPool().query(
    `UPDATE chain_cursors
     SET lease_holder = $3, lease_expires_at = NOW() + ($4 || ' seconds')::INTERVAL,
         lease_generation = lease_generation + 1
     WHERE chain_id = $1 AND stream = $2
       AND (lease_holder IS NULL OR lease_expires_at < NOW())
     RETURNING lease_generation`,
    [chainId, stream, workerId, ttlSeconds],
  );

  if ((rowCount ?? 0) > 0) {
    return { leased: true, leaseGeneration: parseInt(rows[0].lease_generation) };
  }
  return { leased: false, leaseGeneration: 0 };
}

/** releaseLease with workerId guard — only the holder can release */
export async function releaseLease(
  chainId: number,
  stream: string,
  workerId: string,
): Promise<void> {
  await getPool().query(
    `UPDATE chain_cursors
     SET lease_holder = NULL, lease_expires_at = NULL
     WHERE chain_id = $1 AND stream = $2 AND lease_holder = $3`,
    [chainId, stream, workerId],
  );
}

// ── Raw Event Insertion ──────────────────────

export async function insertRawEvents(
  client: PoolClient,
  events: RawEventRow[],
): Promise<number> {
  if (events.length === 0) return 0;

  const values: Array<unknown> = [];
  const placeholders: string[] = [];
  let idx = 1;

  for (const ev of events) {
    placeholders.push(
      `($${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++},$${idx++}::jsonb,$${idx++}::jsonb,$${idx++},'PENDING_CONFIRMATION')`,
    );
    values.push(
      ev.chain_id,
      ev.contract_address,
      ev.event_name ?? "unknown",
      ev.transaction_hash,
      ev.log_index,
      ev.block_number,
      ev.block_hash,
      ev.transaction_index ?? null,
      ev.block_timestamp,
      JSON.stringify(ev.decoded_data),
      JSON.stringify(ev.topics),
      ev.raw_data ?? null,
    );
  }

  const query = `INSERT INTO chain_raw_events
    (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, raw_data, status)
    VALUES ${placeholders.join(",")}
    ON CONFLICT (chain_id, transaction_hash, log_index, block_hash) DO NOTHING`;

  const result = await client.query(query, values);
  return result.rowCount ?? 0;
}

// ── Delete raw events + projection for reorg ──

export async function deleteRawEvents(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
): Promise<number> {
  const { rowCount } = await client.query(
    `DELETE FROM chain_raw_events WHERE chain_id = $1 AND block_number = $2 AND status = 'PENDING_CONFIRMATION'`,
    [chainId, blockNumber],
  );
  return rowCount ?? 0;
}

export async function deleteProjections(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
): Promise<number> {
  const { rowCount } = await client.query(
    `DELETE FROM transaction_projections WHERE chain_id = $1 AND block_number = $2`,
    [chainId, blockNumber],
  );
  return rowCount ?? 0;
}

// ── Reorg Detection ──────────────────────────

export async function findReorgedBlocks(
  client: PoolClient,
  chainId: number,
  fromBlock: number,
  toBlock: number,
): Promise<Array<{ blockNumber: number; storedHash: string; actualHash: string }>> {
  const { rows } = await client.query(
    `SELECT DISTINCT block_number, block_hash FROM chain_raw_events
     WHERE chain_id = $1 AND block_number BETWEEN $2 AND $3 AND status = 'CONFIRMED'
     ORDER BY block_number`,
    [chainId, fromBlock, toBlock],
  );

  return rows.map(row => ({
    blockNumber: parseInt(row.block_number),
    storedHash: row.block_hash as string,
    actualHash: "", // filled by caller via RPC
  }));
}

/** Mark all events in a block as REORGED */
export async function markBlockReorged(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
): Promise<number> {
  const { rowCount } = await client.query(
    `UPDATE chain_raw_events SET status = 'REORGED', reorged_at = NOW(), updated_at = NOW()
     WHERE chain_id = $1 AND block_number = $2 AND status != 'REORGED'`,
    [chainId, blockNumber],
  );
  return rowCount ?? 0;
}

// ── Confirmation ─────────────────────────────

/** Confirm events once block depth >= CONFIRMATION_BLOCKS */
export async function confirmEvents(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
): Promise<number> {
  const { rowCount } = await client.query(
    `UPDATE chain_raw_events SET status = 'CONFIRMED', confirmed_at = NOW(), updated_at = NOW()
     WHERE chain_id = $1 AND block_number = $2 AND status = 'PENDING_CONFIRMATION'`,
    [chainId, blockNumber],
  );
  return rowCount ?? 0;
}

/** Get the oldest unconfirmed block number */
export async function getOldestUnconfirmedBlock(
  client: PoolClient,
  chainId: number,
): Promise<number | null> {
  const { rows } = await client.query(
    `SELECT block_number FROM chain_raw_events
     WHERE chain_id = $1 AND status = 'PENDING_CONFIRMATION'
     ORDER BY block_number ASC LIMIT 1`,
    [chainId],
  );
  return rows.length > 0 ? parseInt(rows[0].block_number) : null;
}

/** Check if a lease is currently valid */
export async function checkLeaseValid(
  client: PoolClient,
  chainId: number,
  stream: string,
  leaseGeneration: number,
  workerId: string,
): Promise<boolean> {
  const { rows } = await client.query(
    `SELECT lease_generation, lease_holder, lease_expires_at
     FROM chain_cursors WHERE chain_id = $1 AND stream = $2`,
    [chainId, stream],
  );
  if (rows.length === 0) return false;
  const gen = parseInt(rows[0].lease_generation ?? "0");
  const holder = rows[0].lease_holder as string | null;
  const expires = rows[0].lease_expires_at as Date | null;
  return gen === leaseGeneration && holder === workerId
    && expires !== null && expires > new Date();
}
