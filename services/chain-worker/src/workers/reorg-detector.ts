// PANGU2 Chain Worker — Reorg Detector
// Hash-scoped: only marks stale hash events, not entire block number.
// Global maintenance lease ensures scanner coordination.
// Empty-block detection via checkpoint table (not raw events).

import { createPublicClient, http, type PublicClient } from "viem";
import { type PoolClient } from "pg";
import {
  getPool, findReorgedBlocks, getBlockCheckpointsInRange,
  markBlockReorgedHashScoped, markPendingsReorged, deleteProjectionsHashScoped,
  acquireMaintenanceLease, releaseMaintenanceLease, validateMaintenanceLease,
  rewindCursorMaintenance, getAllScannerStreams,
} from "../db/client";
import { CHAIN_ID, RPC_URL, REORG_DEPTH, WORKER_ID, LEASE_TTL_SECONDS } from "../config";

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
  const { leased, leaseGeneration } = await acquireMaintenanceLease(CHAIN_ID, holdId, LEASE_TTL_SECONDS);
  if (!leased) return;

  const pool = getPool();
  const db = await pool.connect();
  try {
    // Validate the maintenance lease is still held
    if (!await validateMaintenanceLease(db, CHAIN_ID, holdId, leaseGeneration)) {
      console.warn("[Reorg] maintenance lease invalidated");
      return;
    }

    // 1. Hash-scoped check: raw events with stored hashes
    const suspect = await findReorgedBlocks(db, CHAIN_ID, fromBlock, currentBlock);
    for (const s of suspect) {
      const block = await c.getBlock({ blockNumber: BigInt(s.blockNumber) }).catch(() => null);
      if (!block) continue;
      const actualHash = (block.hash as string).toLowerCase();
      if (actualHash !== s.storedHash) {
        await handleReorg(db, CHAIN_ID, s.blockNumber, s.storedHash, holdId, leaseGeneration);
      }
    }

    // 2. Empty-block detection: checkpoints in range
    const checkpoints = await getBlockCheckpointsInRange(db, CHAIN_ID, fromBlock, currentBlock);
    for (const cp of checkpoints) {
      // Skip blocks already found in raw-events suspect (dedup)
      if (suspect.some(s => s.blockNumber === cp.blockNumber)) continue;
      const block = await c.getBlock({ blockNumber: BigInt(cp.blockNumber) }).catch(() => null);
      if (!block) continue;
      const actualHash = (block.hash as string).toLowerCase();
      if (actualHash !== cp.storedHash) {
        console.log(`[Reorg] empty block #${cp.blockNumber}: checkpoint mismatch, stored=${cp.storedHash.slice(0,10)}, actual=${actualHash.slice(0,10)}`);
        await handleReorg(db, CHAIN_ID, cp.blockNumber, cp.storedHash, holdId, leaseGeneration);
      }
    }
  } finally {
    db.release();
    await releaseMaintenanceLease(CHAIN_ID, holdId, leaseGeneration);
  }
}

async function handleReorg(
  db: PoolClient, chainId: number, blockNumber: number, staleHash: string,
  holdId: string, leaseGeneration: number,
): Promise<void> {
  try {
    await db.query("BEGIN");

    // Re-validate maintenance lease inside transaction
    if (!await validateMaintenanceLease(db, chainId, holdId, leaseGeneration)) {
      console.warn("[Reorg] lease expired during reorg, rolling back");
      await db.query("ROLLBACK");
      return;
    }

    // 1. Mark stale-hash events as REORGED (CONFIRMED + PENDING)
    const cReorged = await markBlockReorgedHashScoped(db, chainId, blockNumber, staleHash);
    const pReorged = await markPendingsReorged(db, chainId, blockNumber, staleHash);

    // 2. Delete projections for stale hash only
    const deletedProj = await deleteProjectionsHashScoped(db, chainId, blockNumber, staleHash);

    // 3. Rewind ALL scanner streams
    const streams = await getAllScannerStreams(db, chainId);
    const rewindTo = blockNumber - 1;
    let rewoundCount = 0;
    let failCount = 0;

    for (const s of streams) {
      if (s.last_scanned_block > rewindTo) {
        const ok = await rewindCursorMaintenance(db, chainId, s.stream, rewindTo);
        if (ok) rewoundCount++; else failCount++;
      }
    }

    // Fail if any stream that needed rewind failed
    if (failCount > 0) {
      console.error(`[Reorg] ${failCount} streams failed to rewind, rolling back`);
      await db.query("ROLLBACK");
      return;
    }

    await db.query("COMMIT");
    console.log(
      `[Reorg] block #${blockNumber} hash=${staleHash.slice(0,10)}: ` +
      `${cReorged} CONFIRMED + ${pReorged} PENDING marked REORGED, ${deletedProj} projections deleted, ` +
      `${rewoundCount} streams rewound to ${rewindTo}`,
    );
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  }
}
