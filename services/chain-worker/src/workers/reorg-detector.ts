// PANGU2 Chain Worker — Reorg Detector
// Checks block hashes in the reorg window against RPC.
// On mismatch: marks raw events REORGED, deletes projections, rewinds cursor.
// All operations happen atomically in a single DB transaction.

import { createPublicClient, http, type PublicClient } from "viem";
import {
  getPool, findReorgedBlocks, markBlockReorged, deleteProjections,
  acquireLease, releaseLease, getCursor, upsertCursor,
} from "../db/client";
import { CHAIN_ID, RPC_URL, REORG_DEPTH, WORKER_ID, LEASE_TTL_SECONDS, rpcLogLabel } from "../config";

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) });
  return rpc;
}

export async function startReorgDetection(): Promise<void> {
  console.log(`[Reorg] depth=${REORG_DEPTH}`);
  await checkReorgs();
  setInterval(() => checkReorgs().catch(e => console.error("[Reorg]", e)), 60_000);
}

async function checkReorgs(): Promise<void> {
  const c = getRpc();
  const currentBlock = Number(await c.getBlockNumber());
  const fromBlock = Math.max(0, currentBlock - REORG_DEPTH);
  const streams = ["TRADE_EVENTS", "DIVIDEND_EVENTS"];

  for (const stream of streams) {
    const holderId = `reorg-${WORKER_ID}`;
    const { leased, leaseGeneration } = await acquireLease(CHAIN_ID, stream, holderId, LEASE_TTL_SECONDS);
    if (!leased) continue;

    const pool = getPool();
    const db = await pool.connect();
    try {
      const suspect = await findReorgedBlocks(db, CHAIN_ID, fromBlock, currentBlock);
      for (const s of suspect) {
        try {
          const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) });
          const actualHash = (block.hash as string).toLowerCase();
          if (actualHash !== s.storedHash) {
            console.log(`[Reorg] ${stream}: block #${s.blockNumber} reorged (stored=${s.storedHash.slice(0,10)}, actual=${actualHash.slice(0,10)})`);

            // All operations in a single atomic transaction
            await db.query("BEGIN");

            // 1. Mark raw events as REORGED
            const reorged = await markBlockReorged(db, CHAIN_ID, s.blockNumber);

            // 2. Delete projections for the reorged block
            const deletedProj = await deleteProjections(db, CHAIN_ID, s.blockNumber);

            // 3. Rewind cursor to safe point
            const cursor = await getCursor(db, CHAIN_ID, stream);
            const rewindTo = s.blockNumber - 1;
            if (cursor && cursor.last_scanned_block > rewindTo) {
              // Use lease_generation for fencing — only the current lease holder can rewind
              const written = await upsertCursor(
                db, CHAIN_ID, stream, rewindTo, null,
                "REORG_RECOVERY", leaseGeneration,
              );
              if (!written) {
                console.warn(`[Reorg] ${stream}: cursor rewind rejected — lease stale`);
                await db.query("ROLLBACK");
                continue;
              }
            }

            await db.query("COMMIT");
            console.log(
              `[Reorg] ${stream}: block #${s.blockNumber} handled — ` +
              `${reorged} events marked REORGED, ${deletedProj} projections deleted, cursor rewound to ${rewindTo}`,
            );
          }
        } catch (e) {
          await db.query("ROLLBACK").catch(() => {});
          console.error(`[Reorg] ${stream} block #${s.blockNumber}`, e);
        }
      }
    } finally {
      db.release();
      await releaseLease(CHAIN_ID, stream, holderId);
    }
  }
}
