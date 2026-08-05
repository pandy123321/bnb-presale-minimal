// PANGU2 Chain Worker — Confirmation Worker
// Confirms PENDING_CONFIRMATION events once block depth >= CONFIRMATION_BLOCKS.
// Uses real RPC chain head (getBlockNumber) instead of cursor max for safety.

import { createPublicClient, http, type PublicClient } from "viem";
import { getPool, confirmEvents } from "../db/client";
import { CHAIN_ID, CONFIRMATION_BLOCKS, RPC_URL } from "../config";

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) });
  return rpc;
}

export async function startConfirmationWorker(): Promise<void> {
  console.log(`[Confirmation] Starting — depth=${CONFIRMATION_BLOCKS}`);
  await processConfirmations();
  setInterval(() => processConfirmations().catch(e => console.error("[Confirmation]", e)), 15_000);
}

async function processConfirmations(): Promise<void> {
  const c = getRpc();
  const pool = getPool();
  const db = await pool.connect();
  try {
    // Use real RPC chain head — not cursor max — for safety
    const rpcChainHead = Number(await c.getBlockNumber());
    const safeThreshold = rpcChainHead - CONFIRMATION_BLOCKS;

    // Find unconfirmed blocks below the safe threshold
    const { rows } = await db.query(
      `SELECT DISTINCT block_number FROM chain_raw_events
       WHERE chain_id = $1 AND status = 'PENDING_CONFIRMATION' AND block_number <= $2
       ORDER BY block_number ASC`,
      [CHAIN_ID, safeThreshold],
    );

    if (rows.length === 0) return;

    let totalConfirmed = 0;
    for (const row of rows) {
      const bn = Number(row.block_number);
      await db.query("BEGIN");
      const count = await confirmEvents(db, CHAIN_ID, bn);
      await db.query("COMMIT");
      totalConfirmed += count;
    }
    if (totalConfirmed > 0) {
      console.log(`[Confirmation] ${totalConfirmed} events confirmed (chain head #${rpcChainHead}, threshold #${safeThreshold})`);
    }
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  } finally { db.release(); }
}
