// PANGU2 Chain Worker — Confirmation Worker
// Confirms PENDING events once block depth >= CONFIRMATION_BLOCKS.
// Validates canonical hash from RPC; marks stale-hash events REORGED on mismatch.

import { createPublicClient, http, type PublicClient } from "viem";
import { getPool, confirmEvents, markPendingsReorged, deleteProjectionsHashScoped, rewindCursorMaintenance, getAllScannerStreams, findPendingBlocksToConfirm } from "../db/client";
import { CHAIN_ID, CONFIRMATION_BLOCKS, RPC_URL } from "../config";

let rpc: PublicClient | null = null;
function getRpc(): PublicClient { if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) }); return rpc; }

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

    const candidates = await findPendingBlocksToConfirm(db, CHAIN_ID, safeThreshold);
    if (candidates.length === 0) return;

    let totalConfirmed = 0;
    let totalReorged = 0;

    for (const cand of candidates) {
      const bn = cand.blockNumber;
      const block = await c.getBlock({ blockNumber: BigInt(bn) }).catch(() => null);
      if (!block) continue;
      const canonicalHash = (block.hash as string).toLowerCase();
      const storedHash = cand.storedHash.toLowerCase();

      if (storedHash !== canonicalHash) {
        // Hash mismatch — stale hash detected before confirmation
        console.log(`[Confirmation] block #${bn}: stored=${storedHash.slice(0,10)} != canonical=${canonicalHash.slice(0,10)} → reorg recovery`);
        try {
          await db.query("BEGIN");
          const reorged = await markPendingsReorged(db, CHAIN_ID, bn, storedHash);
          await deleteProjectionsHashScoped(db, CHAIN_ID, bn, storedHash);

          // Rewind scanner streams
          const streams = await getAllScannerStreams(db, CHAIN_ID);
          const rewindTo = bn - 1;
          let rewoundCount = 0;
          for (const s of streams) {
            if (s.last_scanned_block > rewindTo) {
              const ok = await rewindCursorMaintenance(db, CHAIN_ID, s.stream, rewindTo);
              if (ok) rewoundCount++;
            }
          }
          await db.query("COMMIT");
          totalReorged += reorged;
          console.log(`[Confirmation] block #${bn}: ${reorged} PENDING marked REORGED, ${rewoundCount} streams rewound to ${rewindTo}`);
        } catch (e) {
          await db.query("ROLLBACK").catch(() => {});
          console.error(`[Confirmation] block #${bn} reorg recovery failed`, e);
        }
      } else {
        // Hash matches — confirm
        await db.query("BEGIN");
        const count = await confirmEvents(db, CHAIN_ID, bn, canonicalHash);
        await db.query("COMMIT");
        totalConfirmed += count;
      }
    }

    if (totalConfirmed > 0 || totalReorged > 0) {
      console.log(`[Confirmation] ${totalConfirmed} confirmed, ${totalReorged} stale events recovered (head #${rpcChainHead})`);
    }
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  } finally { db.release(); }
}
