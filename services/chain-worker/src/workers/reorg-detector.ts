// PANGU2 Chain Worker — Reorg Detector

import { createPublicClient, http, type PublicClient } from "viem";
import { getPool, findReorgedBlocks, markBlockReorged, acquireLease, releaseLease } from "../db/client";
import { CHAIN_ID, RPC_URL, REORG_DEPTH, WORKER_ID, LEASE_TTL_SECONDS, rpcLogLabel } from "../config";

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) });
  return rpc;
}

export async function startReorgDetection(): Promise<void> {
  console.log(`[Reorg] Starting — depth=${REORG_DEPTH}, RPC=${rpcLogLabel()}`);
  await checkReorgs();
  setInterval(() => checkReorgs().catch(e => console.error("[Reorg]", e)), 60_000);
}

async function checkReorgs(): Promise<void> {
  const c = getRpc();
  const currentBlock = Number(await c.getBlockNumber());
  const fromBlock = Math.max(0, currentBlock - REORG_DEPTH);

  // Streams to check — must match scanner stream names
  const streams = ["TRADE_EVENTS", "DIVIDEND_EVENTS"];

  for (const stream of streams) {
    // Acquire the SAME lease the scanner uses — prevents concurrent cursor modification
    const leased = await acquireLease(CHAIN_ID, stream, `reorg-${WORKER_ID}`, LEASE_TTL_SECONDS);
    if (!leased) {
      console.log(`[Reorg] Skipping ${stream} — lease held by scanner`);
      continue;
    }

    const p = getPool();
    const db = await p.connect();
    try {
      const suspect = await findReorgedBlocks(db, CHAIN_ID, fromBlock, currentBlock);
      for (const s of suspect) {
        try {
          const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) });
          const actualHash = (block.hash as string).toLowerCase();
          if (actualHash !== s.storedHash) {
            console.log(`[Reorg] Block #${s.blockNumber} reorged in ${stream}`);

            await db.query("BEGIN");
            await markBlockReorged(db, CHAIN_ID, s.blockNumber);
            // Rewind cursor for this specific stream
            await db.query(
              `UPDATE chain_cursors
               SET last_scanned_block = LEAST($1, last_scanned_block)
               WHERE chain_id = $2 AND stream = $3`,
              [s.blockNumber - 1, CHAIN_ID, stream],
            );
            await db.query("COMMIT");
            console.log(`[Reorg] Cursor for ${stream} rewound to ${s.blockNumber - 1}`);
          }
        } catch (e) {
          console.error(`[Reorg] Block #${s.blockNumber} in ${stream} failed`, e);
          try { await db.query("ROLLBACK"); } catch {}
        }
      }
    } finally {
      db.release();
      await releaseLease(CHAIN_ID, stream);
    }
  }
}
