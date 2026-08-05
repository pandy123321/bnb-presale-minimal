// PANGU2 Chain Worker — Reorg Detector

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
    const { leased } = await acquireLease(CHAIN_ID, stream, `reorg-${WORKER_ID}`, LEASE_TTL_SECONDS);
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
            console.log(`[Reorg] ${stream}: block #${s.blockNumber} reorged`);
            await db.query("BEGIN");
            await markBlockReorged(db, CHAIN_ID, s.blockNumber);
            await deleteProjections(db, CHAIN_ID, s.blockNumber);
            const cursor = await getCursor(db, CHAIN_ID, stream);
            const rewindTo = s.blockNumber - 1;
            if (cursor && cursor.last_scanned_block > rewindTo) {
              await upsertCursor(db, CHAIN_ID, stream, rewindTo, null, "REORG_RECOVERY");
            }
            await db.query("COMMIT");
            console.log(`[Reorg] ${stream}: cursor rewound to ${rewindTo}`);
          }
        } catch (e) {
          console.error(`[Reorg] ${stream} block #${s.blockNumber}`, e);
          await db.query("ROLLBACK").catch(() => {});
        }
      }
    } finally {
      db.release();
      await releaseLease(CHAIN_ID, stream, `reorg-${WORKER_ID}`);
    }
  }
}
