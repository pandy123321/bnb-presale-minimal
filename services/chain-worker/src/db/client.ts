// PANGU2 Chain Worker — Database Layer
// PostgreSQL client for raw events, cursors, projections, checkpoints and outbox writes.

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

// ── Schema Version ──────────────────────────

const REQUIRED_SCHEMA_VERSION = 2;

export async function verifySchemaVersion(): Promise<void> {
  const { rows } = await getPool().query(
    `SELECT COALESCE(schema_version, 0) AS v FROM chain_cursors_settings LIMIT 1`,
  );
  const version = rows.length > 0 ? parseInt(rows[0].v) : 0;
  if (version < REQUIRED_SCHEMA_VERSION) {
    throw new Error(
      `Schema version ${version} < ${REQUIRED_SCHEMA_VERSION}. Run migration first.`,
    );
  }
}

// ── Block Checkpoints ───────────────────────

export async function insertBlockCheckpoint(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
  blockHash: string,
): Promise<void> {
  await client.query(
    `INSERT INTO chain_block_checkpoints (chain_id, block_number, block_hash, created_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (chain_id, block_number) DO UPDATE
       SET block_hash = $3, created_at = NOW()`,
    [chainId, blockNumber, blockHash],
  );
}

export async function getBlockCheckpoint(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
): Promise<string | null> {
  const { rows } = await client.query(
    `SELECT block_hash FROM chain_block_checkpoints
     WHERE chain_id = $1 AND block_number = $2`,
    [chainId, blockNumber],
  );
  return rows.length > 0 ? (rows[0].block_hash as string) : null;
}

/** Find blocks in range that have NO checkpoint — used for empty-block reorg detection */
export async function findMissingCheckpoints(
  client: PoolClient,
  chainId: number,
  fromBlock: number,
  toBlock: number,
): Promise<Array<{ blockNumber: number; storedHash: string }>> {
  const { rows } = await client.query(
    `SELECT DISTINCT e.block_number, cb.block_hash
     FROM chain_raw_events e
     LEFT JOIN chain_block_checkpoints cb
       ON cb.chain_id = e.chain_id AND cb.block_number = e.block_number
     WHERE e.chain_id = $1
       AND e.block_number BETWEEN $2 AND $3
       AND e.status = 'CONFIRMED'
       AND cb.block_hash IS NULL
     ORDER BY e.block_number`,
    [chainId, fromBlock, toBlock],
  );
  return rows.map(r => ({ blockNumber: parseInt(r.block_number), storedHash: "" }));
}

// ── Cursor Operations ────────────────────────

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

/** upsertCursor — triple-fenced: holder, generation, expires_at > NOW() */
export async function upsertCursor(
  client: PoolClient,
  chainId: number,
  stream: string,
  blockNumber: number,
  blockHash: string | null,
  status: string = "HEALTHY",
  workerId: string,
  leaseGeneration: number,
): Promise<boolean> {
  const { rowCount } = await client.query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, last_scanned_block_hash, status, last_run_completed_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     ON CONFLICT (chain_id, stream)
     DO UPDATE SET last_scanned_block = $3, last_scanned_block_hash = $4, status = $5, last_run_completed_at = NOW(), updated_at = NOW()
     WHERE chain_cursors.lease_generation = $6
       AND chain_cursors.lease_holder = $7
       AND chain_cursors.lease_expires_at > NOW()`,
    [chainId, stream, blockNumber, blockHash, status, leaseGeneration, workerId],
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
  await getPool().query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_generation)
     VALUES ($1, $2, 0, 'PENDING', 0)
     ON CONFLICT (chain_id, stream) DO NOTHING`,
    [chainId, stream],
  );

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

/** releaseLease — validates workerId AND lease_generation; only current holder can release */
export async function releaseLease(
  chainId: number,
  stream: string,
  workerId: string,
  leaseGeneration: number,
): Promise<void> {
  await getPool().query(
    `UPDATE chain_cursors
     SET lease_holder = NULL, lease_expires_at = NULL
     WHERE chain_id = $1 AND stream = $2
       AND lease_holder = $3
       AND lease_generation = $4`,
    [chainId, stream, workerId, leaseGeneration],
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
      ev.chain_id, ev.contract_address, ev.event_name ?? "unknown",
      ev.transaction_hash, ev.log_index, ev.block_number, ev.block_hash,
      ev.transaction_index ?? null, ev.block_timestamp,
      JSON.stringify(ev.decoded_data), JSON.stringify(ev.topics),
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
    actualHash: "",
  }));
}

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

/** Rewind cursor for a stream — only with valid lease_fencing */
export async function rewindCursor(
  client: PoolClient,
  chainId: number,
  stream: string,
  rewindTo: number,
  workerId: string,
  leaseGeneration: number,
): Promise<boolean> {
  const { rowCount } = await client.query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
     VALUES ($1, $2, $3, 'REORG_RECOVERY', NOW())
     ON CONFLICT (chain_id, stream)
     DO UPDATE SET last_scanned_block = $3, status = 'REORG_RECOVERY', updated_at = NOW()
     WHERE chain_cursors.lease_generation = $4
       AND chain_cursors.lease_holder = $5
       AND chain_cursors.lease_expires_at > NOW()`,
    [chainId, stream, rewindTo, leaseGeneration, workerId],
  );
  return (rowCount ?? 0) > 0;
}

// ── Confirmation ─────────────────────────────

/** Confirm events — validates canonical block hash before confirming */
export async function confirmEvents(
  client: PoolClient,
  chainId: number,
  blockNumber: number,
  canonicalHash: string,
): Promise<number> {
  const { rowCount } = await client.query(
    `UPDATE chain_raw_events SET status = 'CONFIRMED', confirmed_at = NOW(), updated_at = NOW()
     WHERE chain_id = $1 AND block_number = $2
       AND status = 'PENDING_CONFIRMATION'
       AND block_hash = $3`,
    [chainId, blockNumber, canonicalHash],
  );
  return rowCount ?? 0;
}

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

/** Check that a cursor has an active lease (NOT NULL holder with unexpired lease) */
export async function cursorHasActiveLease(
  client: PoolClient,
  chainId: number,
  stream: string,
): Promise<boolean> {
  const { rows } = await client.query(
    `SELECT lease_holder, lease_expires_at FROM chain_cursors
     WHERE chain_id = $1 AND stream = $2`,
    [chainId, stream],
  );
  if (rows.length === 0) return false;
  const holder = rows[0].lease_holder as string | null;
  const expires = rows[0].lease_expires_at as Date | null;
  return holder !== null && expires !== null && expires > new Date();
}

// ── All-stream cursor query ──────────────────

export async function getAllCursorStreams(
  client: PoolClient,
  chainId: number,
): Promise<Array<{ stream: string; last_scanned_block: number }>> {
  const { rows } = await client.query(
    `SELECT stream, last_scanned_block FROM chain_cursors WHERE chain_id = $1`,
    [chainId],
  );
  return rows.map(r => ({
    stream: r.stream as string,
    last_scanned_block: parseInt(r.last_scanned_block),
  }));
}
