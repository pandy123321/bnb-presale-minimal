// PANGU2 Chain Worker — Reorg Detector
// Periodically checks confirmed blocks against RPC to detect chain reorgs.

import { createPublicClient, http, type PublicClient } from "viem";
import { anvil } from "viem/chains";
import { getPool, findReorgedBlocks, markBlockReorged } from "../db/client";

const CHAIN_ID = parseInt(process.env.CHAIN_ID ?? "31337");
const RPC_URL = process.env.RPC_URL ?? "http://localhost:8545";
const REORG_DEPTH = parseInt(process.env.REORG_DEPTH ?? "20");
const REORG_CHECK_INTERVAL_SECONDS = parseInt(process.env.REORG_CHECK_INTERVAL ?? "60");

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ chain: { ...anvil, id: CHAIN_ID }, transport: http(RPC_URL) });
  return rpc;
}

export async function startReorgDetection(): Promise<void> {
  console.log(`[Reorg] Starting — depth=${REORG_DEPTH}, interval=${REORG_CHECK_INTERVAL_SECONDS}s`);
  await checkReorgs();
  setInterval(() => checkReorgs().catch(e => console.error("[Reorg]", e)), REORG_CHECK_INTERVAL_SECONDS * 1000);
}

async function checkReorgs(): Promise<void> {
  const c = getRpc();
  const p = getPool();
  const db = await p.connect();
  try {
    const currentBlock = Number(await c.getBlockNumber());
    const fromBlock = Math.max(0, currentBlock - REORG_DEPTH);
    const suspect = await findReorgedBlocks(db, CHAIN_ID, fromBlock, currentBlock);
    for (const s of suspect) {
      try {
        const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) });
        const actualHash = (block.hash as string).toLowerCase();
        if (actualHash !== s.storedHash) {
          console.log(`[Reorg] Block #${s.blockNumber} reorged`);
          await db.query("BEGIN");
          await markBlockReorged(db, CHAIN_ID, s.blockNumber);

          // Rewind cursor to reorg point so canonical chain is rescanned
          await db.query(
            `UPDATE chain_cursors SET last_scanned_block = $1 - 1 WHERE chain_id = $2 AND last_scanned_block >= $1`,
            [s.blockNumber, CHAIN_ID],
          );
          await db.query("COMMIT");

          // Signal scanner to re-process the affected range
          console.log(`[Reorg] Cursor rewound to block ${s.blockNumber - 1} — rescan required`);
        }
      } catch (e) {
        console.error(`[Reorg] Block #${s.blockNumber} check failed`, e);
        try { await db.query("ROLLBACK"); } catch {}
      }
    }
  } finally { db.release(); }
}
