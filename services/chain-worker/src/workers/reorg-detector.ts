// PANGU2 Chain Worker — Reorg Detector
// Checks block hashes across ALL streams and block checkpoints.
// On mismatch: marks raw events REORGED, deletes projections, rewinds ALL affected streams globally.

import { createPublicClient, http, type PublicClient } from "viem";
import {
  getPool, findReorgedBlocks, findMissingCheckpoints, markBlockReorged,
  deleteProjections, acquireLease, releaseLease, rewindCursor,
  getAllCursorStreams, getBlockCheckpoint,
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
  const holdId = `reorg-${WORKER_ID}`;
  const { leased, leaseGeneration } = await acquireLease(CHAIN_ID, "REORG_GLOBAL", holdId, LEASE_TTL_SECONDS);
  if (!leased) return;

  const pool = getPool();
  const db = await pool.connect();
  try {
    const suspect = await findReorgedBlocks(db, CHAIN_ID, fromBlock, currentBlock);
    const emptySuspect = await findMissingCheckpoints(db, CHAIN_ID, fromBlock, currentBlock);

    for (const s of suspect) {
      const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) }).catch(() => null);
      if (!block) continue;
      const actualHash = (block.hash as string).toLowerCase();
      if (actualHash !== s.storedHash) {
        await handleReorg(db, CHAIN_ID, s.blockNumber, holdId, leaseGeneration);
      }
    }

    for (const s of emptySuspect) {
      const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) }).catch(() => null);
      if (!block) continue;
      const actualHash = (block.hash as string).toLowerCase();
      const cpHash = await getBlockCheckpoint(db, CHAIN_ID, s.blockNumber);
      if (cpHash && cpHash !== actualHash) {
        console.log(`[Reorg] empty block #${s.blockNumber}: checkpoint mismatch`);
        await handleReorg(db, CHAIN_ID, s.blockNumber, holdId, leaseGeneration);
      }
    }
  } finally {
    db.release();
    await releaseLease(CHAIN_ID, "REORG_GLOBAL", holdId, leaseGeneration);
  }
}

async function handleReorg(
  db: import("pg").PoolClient,
  chainId: number, blockNumber: number, workerId: string, leaseGeneration: number,
): Promise<void> {
  await db.query("BEGIN");
  const reorged = await markBlockReorged(db, chainId, blockNumber);
  const deletedProj = await deleteProjections(db, chainId, blockNumber);

  const allStreams = await getAllCursorStreams(db, chainId);
  const rewindTo = blockNumber - 1;
  let rewoundCount = 0;

  for (const stream of allStreams) {
    if (stream.last_scanned_block > rewindTo) {
      const ok = await rewindCursor(db, chainId, stream.stream, rewindTo, workerId, leaseGeneration);
      if (ok) rewoundCount++;
    }
  }
  await db.query("COMMIT");
  console.log(
    `[Reorg] block #${blockNumber}: ${reorged} events REORGED, ${deletedProj} projections deleted, ` +
    `${rewoundCount} streams rewound to ${rewindTo}`,
  );
}
