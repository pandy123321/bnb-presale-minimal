// PANGU2 Chain Worker — Integration Tests
// Tests: cursor/lease fencing, multi-event projection, projection idempotency,
// reorg rollback consistency, transaction failure isolation.

import { describe, it, expect, beforeEach, afterAll } from "vitest";
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.DATABASE_HOST ?? "localhost",
  port: parseInt(process.env.DATABASE_PORT ?? "5432"),
  database: process.env.DATABASE_NAME ?? "bnb_presale",
  user: process.env.DATABASE_USER ?? "bnb",
  password: process.env.DATABASE_PASSWORD ?? "bnb_dev_pass",
});

const CHAIN_ID = 31337;

afterAll(async () => {
  await pool.end();
});

beforeEach(async () => {
  await pool.query("DELETE FROM chain_raw_events");
  await pool.query("DELETE FROM chain_cursors");
  await pool.query("DELETE FROM transaction_projections");
});

// ─────────────────────────────────────────────────────
// Lease Fencing
// ─────────────────────────────────────────────────────

describe("Lease Fencing", () => {
  it("old worker can write while lease is valid", async () => {
    // Setup cursor with lease
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_holder, lease_expires_at, lease_generation)
       VALUES ($1, 'TEST', 100, 'SYNCED', 'w1', NOW() + INTERVAL '120 seconds', 5)`,
      [CHAIN_ID],
    );

    // Write with correct generation should succeed
    const { rowCount } = await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES ($1, 'TEST', 200, 'SYNCED', NOW())
       ON CONFLICT (chain_id, stream)
       DO UPDATE SET last_scanned_block = 200, status = 'SYNCED', updated_at = NOW()
       WHERE chain_cursors.lease_generation = $2`,
      [CHAIN_ID, 5],
    );
    expect(rowCount).toBe(1);
  });

  it("expired worker lease rejects writes from old generation", async () => {
    // Setup cursor with EXPIRED lease held by w1, generation 5
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_holder, lease_expires_at, lease_generation)
       VALUES ($1, 'TEST', 100, 'SYNCED', 'w1', NOW() - INTERVAL '1 seconds', 5)`,
      [CHAIN_ID],
    );

    // Simulate: w2 takes over (lease expired), increments generation to 6
    const { rowCount: acqCount } = await pool.query(
      `UPDATE chain_cursors
       SET lease_holder = 'w2', lease_expires_at = NOW() + INTERVAL '120 seconds',
           lease_generation = lease_generation + 1
       WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW())`,
      [CHAIN_ID, "TEST"],
    );
    expect(acqCount).toBe(1); // w2 should acquire expired lease

    // w1 (gen 5) tries to write — should fail
    const { rowCount } = await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES ($1, 'TEST', 200, 'SYNCED', NOW())
       ON CONFLICT (chain_id, stream)
       DO UPDATE SET last_scanned_block = 200, status = 'SYNCED', updated_at = NOW()
       WHERE chain_cursors.lease_generation = $2`,
      [CHAIN_ID, 5],
    );
    expect(rowCount).toBe(0); // old generation should not be able to write

    // Verify generation is still 6 (w2's generation)
    const { rows } = await pool.query(
      "SELECT lease_generation, lease_holder FROM chain_cursors WHERE chain_id = $1 AND stream = $2",
      [CHAIN_ID, "TEST"],
    );
    expect(parseInt(rows[0].lease_generation)).toBe(6);
    expect(rows[0].lease_holder).toBe("w2");
  });

  it("new worker taking over can write with new generation", async () => {
    // w1 had lease, gen=5, now expired
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_holder, lease_expires_at, lease_generation)
       VALUES ($1, 'TEST', 100, 'SYNCED', 'w1', NOW() - INTERVAL '1 seconds', 5)`,
      [CHAIN_ID],
    );

    // w2 acquires (lease expired)
    const { rowCount: acqCount, rows: acqRows } = await pool.query(
      `UPDATE chain_cursors
       SET lease_holder = 'w2', lease_expires_at = NOW() + INTERVAL '120 seconds',
           lease_generation = lease_generation + 1
       WHERE chain_id = $1 AND stream = $2 AND (lease_holder IS NULL OR lease_expires_at < NOW())
       RETURNING lease_generation`,
      [CHAIN_ID, "TEST"],
    );
    expect(acqCount).toBe(1);
    const newGen = parseInt(acqRows[0].lease_generation);

    // w2 writes with new generation — should succeed
    const { rowCount } = await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES ($1, 'TEST', 200, 'SYNCED', NOW())
       ON CONFLICT (chain_id, stream)
       DO UPDATE SET last_scanned_block = 200, status = 'SYNCED', updated_at = NOW()
       WHERE chain_cursors.lease_generation = $2`,
      [CHAIN_ID, newGen],
    );
    expect(rowCount).toBe(1);
  });
});

// ─────────────────────────────────────────────────────
// Multi-Event Projection
// ─────────────────────────────────────────────────────

describe("Multi-Event Projection", () => {
  async function seedRawEvent(logIndex: number) {
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('ab', 32), $2, 100, '0x' || REPEAT('bb', 32), null, NOW(), '{}', '[]', 'CONFIRMED')
       ON CONFLICT (chain_id, transaction_hash, log_index, block_hash) DO NOTHING`,
      [CHAIN_ID, logIndex],
    );
  }

  it("projects multiple events from the same block", async () => {
    // Insert 2 events from the same block
    await seedRawEvent(0);
    await seedRawEvent(1);

    // Insert 2 more events from a different block
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('cd', 32), 0, 101, '0x' || REPEAT('ee', 32), null, NOW(), '{}', '[]', 'CONFIRMED')`,
      [CHAIN_ID],
    );
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('cd', 32), 1, 101, '0x' || REPEAT('ee', 32), null, NOW(), '{}', '[]', 'CONFIRMED')`,
      [CHAIN_ID],
    );

    // Project all
    const { rows: unprojected } = await pool.query(
      `SELECT e.* FROM chain_raw_events e
       WHERE e.chain_id = $1 AND e.status = 'CONFIRMED'
         AND NOT EXISTS (SELECT 1 FROM transaction_projections p
           WHERE p.chain_id = e.chain_id AND p.transaction_hash = e.transaction_hash
           AND p.block_number = e.block_number AND p.log_index = e.log_index)`,
      [CHAIN_ID],
    );
    expect(unprojected.length).toBe(4);

    // Insert projections
    for (const row of unprojected) {
      await pool.query(
        `INSERT INTO transaction_projections
         (chain_id, transaction_hash, block_number, block_hash, event_name, log_index, from_address, to_address, amount_raw, timestamp, status)
         VALUES ($1,$2,$3,$4,$5,$6,'','','0',NOW(),'CONFIRMED')
         ON CONFLICT (chain_id, transaction_hash, block_number, log_index) DO NOTHING`,
        [CHAIN_ID, row.transaction_hash, row.block_number, row.block_hash, row.event_name,
         parseInt(row.log_index)],
      );
    }

    // Verify 4 projections created
    const { rows: proj } = await pool.query(
      "SELECT COUNT(*) AS c FROM transaction_projections WHERE chain_id = $1",
      [CHAIN_ID],
    );
    expect(parseInt(proj[0].c)).toBe(4);
  });

  it("projects multiple logs from the same transaction", async () => {
    const txHash = "0x" + "12".repeat(32);
    // 3 logs in same tx, same block
    for (let i = 0; i < 3; i++) {
      await pool.query(
        `INSERT INTO chain_raw_events
         (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
         VALUES ($1, '0xaaa', 'BuyExecuted', $2, $3, 100, '0x' || REPEAT('bb', 32), null, NOW(), '{}', '[]', 'CONFIRMED')
         ON CONFLICT (chain_id, transaction_hash, log_index, block_hash) DO NOTHING`,
        [CHAIN_ID, txHash, i],
      );
    }

    // Project all 3
    const { rows: unproj } = await pool.query(
      `SELECT * FROM chain_raw_events WHERE chain_id = $1 AND transaction_hash = $2`,
      [CHAIN_ID, txHash],
    );
    expect(unproj.length).toBe(3);

    for (const row of unproj) {
      await pool.query(
        `INSERT INTO transaction_projections
         (chain_id, transaction_hash, block_number, block_hash, event_name, log_index, from_address, to_address, amount_raw, timestamp, status)
         VALUES ($1,$2,$3,$4,$5,$6,'','','0',NOW(),'CONFIRMED')
         ON CONFLICT (chain_id, transaction_hash, block_number, log_index) DO NOTHING`,
        [CHAIN_ID, row.transaction_hash, row.block_number, row.block_hash, row.event_name,
         parseInt(row.log_index)],
      );
    }

    const { rows: count } = await pool.query(
      "SELECT COUNT(*) AS c, COUNT(DISTINCT log_index) AS distinct_logs FROM transaction_projections WHERE transaction_hash = $1",
      [txHash],
    );
    expect(parseInt(count[0].c)).toBe(3);
    expect(parseInt(count[0].distinct_logs)).toBe(3); // all 3 logs should have distinct log_index values
  });
});

// ─────────────────────────────────────────────────────
// Projection Idempotency
// ─────────────────────────────────────────────────────

describe("Projection Idempotency", () => {
  it("projecting the same event twice is idempotent via ON CONFLICT", async () => {
    // Seed one confirmed event
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('ab', 32), 0, 100, '0x' || REPEAT('bb', 32), null, NOW(), '{}', '[]', 'CONFIRMED')`,
      [CHAIN_ID],
    );

    // Project it
    const params = [CHAIN_ID, "0x" + "ab".repeat(32), 100, "0x" + "bb".repeat(32), "BuyExecuted", 0, "", "", "0"];
    const r1 = await pool.query(
      `INSERT INTO transaction_projections
       (chain_id, transaction_hash, block_number, block_hash, event_name, log_index, from_address, to_address, amount_raw, timestamp, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),'CONFIRMED')
       ON CONFLICT (chain_id, transaction_hash, block_number, log_index) DO NOTHING`,
      params,
    );
    expect(r1.rowCount).toBe(1);

    // Project same event again — should be no-op
    const r2 = await pool.query(
      `INSERT INTO transaction_projections
       (chain_id, transaction_hash, block_number, block_hash, event_name, log_index, from_address, to_address, amount_raw, timestamp, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),'CONFIRMED')
       ON CONFLICT (chain_id, transaction_hash, block_number, log_index) DO NOTHING`,
      params,
    );
    expect(r2.rowCount).toBe(0); // duplicate projection should be skipped

    // Verify only 1 row exists
    const { rows } = await pool.query(
      "SELECT COUNT(*) AS c FROM transaction_projections WHERE chain_id = $1",
      [CHAIN_ID],
    );
    expect(parseInt(rows[0].c)).toBe(1);
  });
});

// ─────────────────────────────────────────────────────
// Reorg Rollback Consistency
// ─────────────────────────────────────────────────────

describe("Reorg Rollback Consistency", () => {
  it("reorg marks events REORGED, deletes projections, rewinds cursor atomically", async () => {
    // Setup: cursor at block 200, events in block 200, projections for block 200
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_holder, lease_expires_at, lease_generation)
       VALUES ($1, 'TEST', 200, 'SYNCED', 'reorg-w1', NOW() + INTERVAL '120 seconds', 3)`,
      [CHAIN_ID],
    );

    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('cd', 32), 0, 200, '0x' || REPEAT('old', 32), null, NOW(), '{}', '[]', 'CONFIRMED')`,
      [CHAIN_ID],
    );

    // Project the event
    await pool.query(
      `INSERT INTO transaction_projections
       (chain_id, transaction_hash, block_number, block_hash, event_name, log_index, from_address, to_address, amount_raw, timestamp, status)
       VALUES ($1, $2, 200, $3, 'BuyExecuted', 0, '', '', '0', NOW(), 'CONFIRMED')`,
      [CHAIN_ID, "0x" + "cd".repeat(32), "0x" + "old".repeat(32)],
    );

    // Simulate reorg: mark events REORGED, delete projections, rewind cursor
    await pool.query("BEGIN");

    const { rowCount: reorged } = await pool.query(
      `UPDATE chain_raw_events SET status = 'REORGED', reorged_at = NOW()
       WHERE chain_id = $1 AND block_number = 200 AND status != 'REORGED'`,
      [CHAIN_ID],
    );
    expect(reorged).toBe(1);

    const { rowCount: deleted } = await pool.query(
      "DELETE FROM transaction_projections WHERE chain_id = $1 AND block_number = 200",
      [CHAIN_ID],
    );
    expect(deleted).toBe(1);

    // Rewind cursor with lease_generation check
    const { rowCount: rewound } = await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES ($1, 'TEST', 199, 'REORG_RECOVERY', NOW())
       ON CONFLICT (chain_id, stream)
       DO UPDATE SET last_scanned_block = 199, status = 'REORG_RECOVERY', updated_at = NOW()
       WHERE chain_cursors.lease_generation = $2`,
      [CHAIN_ID, 3],
    );
    expect(rewound).toBe(1);

    await pool.query("COMMIT");

    // Verify raw events are REORGED
    const { rows: evRows } = await pool.query(
      "SELECT status FROM chain_raw_events WHERE block_number = 200",
    );
    expect(evRows[0].status).toBe("REORGED");

    // Verify projections deleted
    const { rows: projRows } = await pool.query(
      "SELECT COUNT(*) AS c FROM transaction_projections WHERE block_number = 200",
    );
    expect(parseInt(projRows[0].c)).toBe(0);

    // Verify cursor rewound
    const { rows: curRows } = await pool.query(
      "SELECT last_scanned_block, status FROM chain_cursors WHERE stream = 'TEST'",
    );
    expect(parseInt(curRows[0].last_scanned_block)).toBe(199);
    expect(curRows[0].status).toBe("REORG_RECOVERY");
  });
});

// ─────────────────────────────────────────────────────
// Transaction Failure — Cursor Does Not Advance
// ─────────────────────────────────────────────────────

describe("Transaction Failure Isolation", () => {
  it("cursor does not advance when transaction rolls back", async () => {
    // Setup: cursor at block 100
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, lease_holder, lease_expires_at, lease_generation)
       VALUES ($1, 'TEST', 100, 'SYNCED', 'w1', NOW() + INTERVAL '120 seconds', 1)`,
      [CHAIN_ID],
    );

    // Start transaction, insert event, then ROLLBACK (simulating failure)
    await pool.query("BEGIN");
    await pool.query(
      `INSERT INTO chain_raw_events
       (chain_id, contract_address, event_name, transaction_hash, log_index, block_number, block_hash, transaction_index, block_timestamp, decoded_data, topics, status)
       VALUES ($1, '0xaaa', 'BuyExecuted', '0x' || REPEAT('ff', 32), 0, 150, '0x' || REPEAT('gg', 32), null, NOW(), '{}', '[]', 'PENDING_CONFIRMATION')`,
      [CHAIN_ID],
    );
    // Try to update cursor but ROLLBACK
    await pool.query(
      `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, status, updated_at)
       VALUES ($1, 'TEST', 150, 'SYNCED', NOW())
       ON CONFLICT (chain_id, stream)
       DO UPDATE SET last_scanned_block = 150, status = 'SYNCED', updated_at = NOW()
       WHERE chain_cursors.lease_generation = $2`,
      [CHAIN_ID, 1],
    );
    await pool.query("ROLLBACK");

    // Verify cursor is still at 100
    const { rows } = await pool.query(
      "SELECT last_scanned_block FROM chain_cursors WHERE stream = 'TEST'",
    );
    expect(parseInt(rows[0].last_scanned_block)).toBe(100);

    // Verify raw event NOT inserted
    const { rows: evRows } = await pool.query(
      "SELECT COUNT(*) AS c FROM chain_raw_events WHERE block_number = 150",
    );
    expect(parseInt(evRows[0].c)).toBe(0);
  });
});

// ─────────────────────────────────────────────────────
// Cursor Operations (original tests preserved)
// ─────────────────────────────────────────────────────

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
    expect(parseInt(rows[0].last_scanned_block)).toBe(100);
  });
});
