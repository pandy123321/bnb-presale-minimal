// PANGU2 Chain Worker — Integration Tests
// Tests: cursor persistence, event insertion, reorg detection, idempotency

import { describe, it, expect, beforeEach, afterAll } from "vitest";
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.DATABASE_HOST ?? "localhost",
  port: parseInt(process.env.DATABASE_PORT ?? "5432"),
  database: process.env.DATABASE_NAME ?? "bnb_presale",
  user: process.env.DATABASE_USER ?? "bnb",
  password: process.env.DATABASE_PASSWORD ?? "bnb_dev_pass",
});

afterAll(async () => {
  await pool.end();
});

beforeEach(async () => {
  await pool.query("DELETE FROM chain_raw_events");
  await pool.query("DELETE FROM chain_cursors");
});

describe("Cursor Operations", () => {
  it("upserts cursor and retrieves it", async () => {
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES (31337, 'TEST_STREAM', 100, 'HEALTHY', NOW())
       ON CONFLICT (chain_id, stream) DO UPDATE SET last_scanned_block = 100`);

    const { rows } = await pool.query(
      "SELECT last_scanned_block FROM chain_cursors WHERE chain_id = $1 AND stream = $2",
      [31337, "TEST_STREAM"],
    );

    expect(rows[0].last_scanned_block).toBe("100");
  });

  it("acquires and releases lease", async () => {
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES (31337, 'LEASE_TEST', 0, 'HEALTHY', NOW())`);

    // Worker 1 acquires lease
    const r1 = await pool.query(
      `UPDATE chain_cursors SET lease_holder = 'w1', lease_expires_at = NOW() + INTERVAL '120 seconds'
       WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW())`,
      [31337, "LEASE_TEST"],
    );
    expect(r1.rowCount).toBe(1);

    // Worker 2 fails to acquire lease
    const r2 = await pool.query(
      `UPDATE chain_cursors SET lease_holder = 'w2', lease_expires_at = NOW() + INTERVAL '120 seconds'
       WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW())`,
      [31337, "LEASE_TEST"],
    );
    expect(r2.rowCount).toBe(0);
  });
});

describe("Raw Event Insertion", () => {
  it("inserts events and rejects duplicates on unique constraint", async () => {
    const event = {
      chain_id: 31337,
      contract_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      event_name: "BuyExecuted",
      transaction_hash: "0x" + "ab".repeat(32),
      log_index: 0,
      block_number: 100,
      block_hash: "0x" + "bb".repeat(32),
      transaction_index: null,
      block_timestamp: new Date().toISOString(),
    };

    // Insert first
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'{}','[]','PENDING_CONFIRMATION')`,
      [event.chain_id, event.contract_address, event.event_name, event.transaction_hash,
       event.log_index, event.block_number, event.block_hash, event.transaction_index, event.block_timestamp],
    );

    // Try inserting duplicate — should silently skip (ON CONFLICT DO NOTHING)
    const r2 = await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'{}','[]','PENDING_CONFIRMATION')
       ON CONFLICT (chain_id, transaction_hash, log_index, block_hash) DO NOTHING`,
      [event.chain_id, event.contract_address, event.event_name, event.transaction_hash,
       event.log_index, event.block_number, event.block_hash, event.transaction_index, event.block_timestamp],
    );
    expect(r2.rowCount).toBe(0);
  });
});

describe("Reorg Detection", () => {
  it("marks events in a block as REORGED", async () => {
    // Insert confirmed event
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES (31337,'0xaaa','BuyExecuted','0x'||REPEAT('cc',32),0,200,'0x'||REPEAT('dd',32),null,NOW(),'{}','[]','CONFIRMED')`,
    );

    // Get stored block hash
    const { rows: beforeRows } = await pool.query(
      "SELECT DISTINCT block_number, block_hash FROM chain_raw_events WHERE status = 'CONFIRMED'",
    );
    expect(beforeRows.length).toBeGreaterThan(0);

    // Simulate reorg: mark the block as REORGED
    const result = await pool.query(
      `UPDATE chain_raw_events SET status = 'REORGED', reorged_at = NOW()
       WHERE chain_id = $1 AND block_number = $2 AND status != 'REORGED'`,
      [31337, 200],
    );
    expect(result.rowCount).toBe(1);

    // Verify status changed
    const { rows: afterRows } = await pool.query(
      "SELECT status FROM chain_raw_events WHERE block_number = 200",
    );
    expect(afterRows[0].status).toBe("REORGED");
  });
});

describe("Idempotency", () => {
  it("cursor upsert is idempotent", async () => {
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES (31337, 'IDEM_STREAM', 50, 'HEALTHY', NOW())`);

    // Run the same upsert twice
    for (let i = 0; i < 2; i++) {
      await pool.query(
        `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
         VALUES (31337, 'IDEM_STREAM', 50, 'HEALTHY', NOW())
         ON CONFLICT (chain_id, stream) DO UPDATE SET last_scanned_block = 50`);

      const { rows } = await pool.query(
        "SELECT COUNT(*) as c FROM chain_cursors WHERE stream = 'IDEM_STREAM'",
      );
      expect(parseInt(rows[0].c)).toBe(1);
    }
  });
});
