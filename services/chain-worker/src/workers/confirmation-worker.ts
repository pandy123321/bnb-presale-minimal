// PANGU2 Chain Worker — Confirmation Worker
// Confirms PENDING_CONFIRMATION events once block depth >= CONFIRMATION_BLOCKS.
// Validates canonical block hash via RPC before confirming each block.

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
    const rpcChainHead = Number(await c.getBlockNumber());
    const safeThreshold = rpcChainHead - CONFIRMATION_BLOCKS;

    const { rows } = await db.query(
      `SELECT DISTINCT block_number, block_hash FROM chain_raw_events
       WHERE chain_id = $1 AND status = 'PENDING_CONFIRMATION' AND block_number <= $2
       ORDER BY block_number ASC`,
      [CHAIN_ID, safeThreshold],
    );

    if (rows.length === 0) return;

    let totalConfirmed = 0;
    for (const row of rows) {
      const bn = Number(row.block_number);
      const storedHash = row.block_hash as string;

      // Fetch canonical hash from RPC — never trust stored hash alone
      const block = await c.getBlock({ blockNumber: BigInt(bn) }).catch(() => null);
      if (!block) {
        console.warn(`[Confirmation] block #${bn}: RPC fetch failed, skipping`);
        continue;
      }
      const canonicalHash = (block.hash as string).toLowerCase();

      await db.query("BEGIN");
      const count = await confirmEvents(db, CHAIN_ID, bn, canonicalHash);
      await db.query("COMMIT");
      totalConfirmed += count;

      if (count === 0 && storedHash !== canonicalHash) {
        console.warn(`[Confirmation] block #${bn}: hash mismatch (stored=${storedHash.slice(0,10)}, canonical=${canonicalHash.slice(0,10)}) — reorg likely`);
      }
    }
    if (totalConfirmed > 0) {
      console.log(`[Confirmation] ${totalConfirmed} events confirmed (head #${rpcChainHead}, threshold #${safeThreshold})`);
    }
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  } finally { db.release(); }
}
