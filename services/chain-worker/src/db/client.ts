// PANGU2 Chain Worker — Database Layer
// PostgreSQL client for raw events, cursors, and outbox writes.

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
  if (pool) {
    await pool.end();
    pool = null;
  }
}

// ── Cursor Operations ──────────────────────

export async function getCursor(
  chainId: number,
  stream: string,
): Promise<number> {
  const { rows } = await getPool().query(
    `SELECT last_scanned_block FROM chain_cursors WHERE chain_id = $1 AND stream = $2`,
    [chainId, stream],
  );
  if (rows.length > 0) {
    return parseInt(rows[0].last_scanned_block);
  }
  return parseInt(process.env.START_BLOCK ?? "0");
}

export async function upsertCursor(
  chainId: number,
  stream: string,
  blockNumber: number,
  blockHash: string | null,
  status: string = "HEALTHY",
): Promise<void> {
  await getPool().query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, last_scanned_block_hash, status, last_run_completed_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     ON CONFLICT (chain_id, stream)
     DO UPDATE SET last_scanned_block = $3, last_scanned_block_hash = $4, status = $5, last_run_completed_at = NOW(), updated_at = NOW()`,
    [chainId, stream, blockNumber, blockHash, status],
  );
}

// ── Lease (Distributed Lock) ───────────────

export async function acquireLease(
  chainId: number,
  stream: string,
  workerId: string,
  ttlSeconds: number,
): Promise<boolean> {
  // Upsert: insert the stream row if it doesn't exist, then attempt lease acquisition.
  // This fixes the cold-start deadlock where a fresh database has no cursor rows.
  await getPool().query(
    `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status)
     VALUES ($1, $2, 0, 'PENDING')
     ON CONFLICT (chain_id, stream) DO NOTHING`,
    [chainId, stream],
  );

  const { rowCount } = await getPool().query(
    `UPDATE chain_cursors
     SET lease_holder = $3, lease_expires_at = NOW() + ($4 || ' seconds')::INTERVAL
     WHERE chain_id = $1 AND stream = $2
       AND (lease_holder IS NULL OR lease_expires_at < NOW())`,
    [chainId, stream, workerId, ttlSeconds],
  );
  return (rowCount ?? 0) > 0;
}

export async function releaseLease(
  chainId: number,
  stream: string,
): Promise<void> {
  await getPool().query(
    `UPDATE chain_cursors SET lease_holder = NULL, lease_expires_at = NULL WHERE chain_id = $1 AND stream = $2`,
    [chainId, stream],
  );
}

// ── Raw Event Insertion ────────────────────

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

// ── Reorg Detection ────────────────────────

/**
 * Check if a previously confirmed block has been replaced.
 * Compares the stored block_hash against the RPC's block hash at that height.
 */
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

  const reorged: Array<{ blockNumber: number; storedHash: string; actualHash: string }> = [];

  for (const row of rows) {
    const bn = parseInt(row.block_number);
    const storedHash = row.block_hash as string;

    // The actual hash would be checked against the RPC — here we store the structure
    // The worker will call eth_getBlockByNumber to compare
    reorged.push({
      blockNumber: bn,
      storedHash,
      actualHash: "", // filled by the caller via RPC
    });
  }

  return reorged;
}

/**
 * Mark all events in a block as REORGED.
 */
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

/**
 * Mark events as CONFIRMED once block depth is sufficient.
 */
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
