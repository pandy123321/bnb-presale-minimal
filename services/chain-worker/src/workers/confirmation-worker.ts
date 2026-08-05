// PANGU2 Chain Worker — Confirmation Worker
// Confirms PENDING_CONFIRMATION events once block depth >= CONFIRMATION_BLOCKS.

import { getPool, confirmEvents, getOldestUnconfirmedBlock } from "../db/client";
import { CHAIN_ID, CONFIRMATION_BLOCKS } from "../config";

export async function startConfirmationWorker(): Promise<void> {
  console.log(`[Confirmation] Starting — depth=${CONFIRMATION_BLOCKS}`);
  await processConfirmations();
  setInterval(() => processConfirmations().catch(e => console.error("[Confirmation]", e)), 15_000);
}

async function processConfirmations(): Promise<void> {
  const pool = getPool();
  const db = await pool.connect();
  try {
    // Get the latest safe block number
    const { rows: [{ block_number: latestBlock }] } = await db.query(
      `SELECT COALESCE(MAX(last_scanned_block), 0) AS block_number FROM chain_cursors WHERE chain_id = $1`,
      [CHAIN_ID],
    );
    const safeThreshold = Number(latestBlock) - CONFIRMATION_BLOCKS;

    // Find unconfirmed blocks below the safe threshold
    const { rows } = await db.query(
      `SELECT DISTINCT block_number FROM chain_raw_events
       WHERE chain_id = $1 AND status = 'PENDING_CONFIRMATION' AND block_number <= $2
       ORDER BY block_number ASC`,
      [CHAIN_ID, safeThreshold],
    );

    if (rows.length === 0) return;

    for (const row of rows) {
      const bn = Number(row.block_number);
      await db.query("BEGIN");
      const count = await confirmEvents(db, CHAIN_ID, bn);
      await db.query("COMMIT");
      if (count > 0) console.log(`[Confirmation] Block #${bn}: ${count} events confirmed`);
    }
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  } finally { db.release(); }
}
