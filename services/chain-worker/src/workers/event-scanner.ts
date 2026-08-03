// PANGU2 Chain Worker — Event Scanner
//
// Core scanning logic:
// 1. Acquire lease
// 2. Read cursor → determine block range
// 3. Fetch logs via viem getLogs
// 4. Decode events using ABIs
// 5. Insert raw events into PostgreSQL
// 6. Update cursor
// 7. Release lease

import {
  createPublicClient,
  http,
  type PublicClient,
  type Log,
  parseAbiItem,
  decodeEventLog,
  type DecodeEventLogReturnType,
} from "viem";
import { anvil } from "viem/chains";
import { Pool, type PoolClient } from "pg";
import {
  getPool,
  getCursor,
  upsertCursor,
  acquireLease,
  releaseLease,
  insertRawEvents,
  type RawEventRow,
} from "../db/client";
import { getAllEventSignatures } from "../abi/loader";

// ── Config ─────────────────────────────────

const CHAIN_ID = parseInt(process.env.CHAIN_ID ?? "31337");
const RPC_URL = process.env.RPC_URL ?? "http://localhost:8545";
const SCAN_BATCH_SIZE = parseInt(process.env.SCAN_BATCH_SIZE ?? "1000");
const CONFIRMATION_BLOCKS = parseInt(process.env.CONFIRMATION_BLOCKS ?? "12");
const REORG_DEPTH = parseInt(process.env.REORG_DEPTH ?? "20");
const SCAN_INTERVAL_SECONDS = parseInt(process.env.SCAN_INTERVAL_SECONDS ?? "15");
const WORKER_ID = process.env.WORKER_ID ?? "worker-default";
const LEASE_TTL_SECONDS = parseInt(process.env.LEASE_TTL_SECONDS ?? "120");

// ── Stream Definitions ─────────────────────

const STREAMS: Array<{
  name: string;
  contractAddress: string;
  abiName: string;
  startBlock: number;
}> = [
  {
    name: "TRADE_EVENTS",
    contractAddress: process.env.TRADE_ROUTER_ADDRESS ?? "0x0000000000000000000000000000000000000000",
    abiName: "Pangu2TradeRouter",
    startBlock: parseInt(process.env.DEPLOYMENT_BLOCK ?? "0"),
  },
  {
    name: "DIVIDEND_EVENTS",
    contractAddress: process.env.DIVIDEND_ADDRESS ?? "0x0000000000000000000000000000000000000000",
    abiName: "DividendDistributor",
    startBlock: parseInt(process.env.DEPLOYMENT_BLOCK ?? "0"),
  },
];

// ── Main Worker ────────────────────────────

let client: PublicClient | null = null;
let pool: Pool | null = null;
let running = false;

function getClient(): PublicClient {
  if (!client) {
    client = createPublicClient({
      chain: { ...anvil, id: CHAIN_ID },
      transport: http(RPC_URL),
    });
  }
  return client;
}

function getPp(): Pool {
  if (!pool) pool = getPool();
  return pool;
}

export async function start(): Promise<void> {
  console.log("[Chain Worker] Starting...");
  console.log(`  Chain ID: ${CHAIN_ID}`);
  console.log(`  RPC: ${RPC_URL}`);
  console.log(`  Batch size: ${SCAN_BATCH_SIZE}`);
  console.log(`  Confirmation blocks: ${CONFIRMATION_BLOCKS}`);
  console.log(`  Worker ID: ${WORKER_ID}`);

  // Load event signatures for decoding (gives string name → human-readable)
  try {
    getAllEventSignatures();
    console.log("  Event signatures loaded");
  } catch {
    console.log("  ABI files not found — scanning without event name decoding");
  }

  running = true;
  await scanAllStreams();

  // Start periodic scanning
  const timer = setInterval(async () => {
    if (!running) return;
    try {
      await scanAllStreams();
    } catch (err) {
      console.error("[Chain Worker] Scan cycle error:", err);
    }
  }, SCAN_INTERVAL_SECONDS * 1000);

  console.log(`[Chain Worker] Scanning every ${SCAN_INTERVAL_SECONDS}s`);
  console.log("[Chain Worker] Ready.");
}

export async function stop(): Promise<void> {
  running = false;
  if (pool) {
    await pool.end();
    pool = null;
  }
  console.log("[Chain Worker] Stopped.");
}

// ── Scan Logic ─────────────────────────────

async function scanAllStreams(): Promise<void> {
  for (const stream of STREAMS) {
    const acquired = await acquireLease(CHAIN_ID, stream.name, WORKER_ID, LEASE_TTL_SECONDS);
    if (!acquired) {
      console.log(`[Chain Worker] Lease not acquired for ${stream.name} — another worker is active`);
      continue;
    }

    try {
      await scanStream(stream);
    } catch (err) {
      console.error(`[Chain Worker] Error scanning ${stream.name}:`, err);
    } finally {
      await releaseLease(CHAIN_ID, stream.name);
    }
  }
}

async function scanStream(stream: {
  name: string;
  contractAddress: string;
  abiName: string;
  startBlock: number;
}): Promise<void> {
  const c = getClient();
  const p = getPp();
  const dbClient = await p.connect();

  try {
    // 1. Read cursor (fallback to stream-specific startBlock if no cursor exists)
    const fromBlock = Math.max(
      await getCursor(CHAIN_ID, stream.name),
      stream.startBlock,
    );

    // 2. Get current chain height (stop before confirmation depth)
    const currentBlock = Number(await c.getBlockNumber());
    const safeToBlock = currentBlock - CONFIRMATION_BLOCKS;

    if (safeToBlock <= fromBlock) {
      return; // nothing new to scan
    }

    const toBlock = Math.min(fromBlock + SCAN_BATCH_SIZE, safeToBlock);

    console.log(`[Chain Worker] Scanning ${stream.name}: blocks ${fromBlock} → ${toBlock}`);

    // 3. Fetch logs
    const logs = await c.getLogs({
      address: stream.contractAddress as `0x${string}`,
      fromBlock: BigInt(fromBlock),
      toBlock: BigInt(toBlock),
    });

    console.log(`[Chain Worker] Found ${logs.length} logs in ${stream.name}`);

    // 4. Convert to raw events and insert
    const rawEvents: RawEventRow[] = [];

    for (const log of logs) {
      const block = await c.getBlock({ blockNumber: log.blockNumber! });

      rawEvents.push({
        chain_id: CHAIN_ID,
        contract_address: (log.address as string).toLowerCase(),
        event_name: log.topics[0] ?? null,
        transaction_hash: (log.transactionHash as string).toLowerCase(),
        log_index: log.logIndex ?? 0,
        block_number: Number(log.blockNumber),
        block_hash: (log.blockHash as string).toLowerCase(),
        transaction_index: log.transactionIndex ?? null,
        block_timestamp: new Date(Number(block.timestamp) * 1000).toISOString(),
        decoded_data: { topics: log.topics, data: log.data },
        topics: log.topics as string[],
        raw_data: log.data,
        status: "PENDING_CONFIRMATION",
      });
    }

    // 5. Insert in transaction
    await dbClient.query("BEGIN");
    try {
      await insertRawEvents(dbClient, rawEvents);

      // Mark all scanned blocks as CONFIRMED (toBlock is already safe)
      for (let bn = fromBlock; bn <= toBlock; bn++) {
        await dbClient.query(
          `UPDATE chain_raw_events SET status = 'CONFIRMED', confirmed_at = NOW()
           WHERE chain_id = $1 AND block_number = $2 AND status = 'PENDING_CONFIRMATION'`,
          [CHAIN_ID, bn],
        );
      }

      // 6. Update cursor with block hash
      const hashBlock = Math.min(toBlock, safeToBlock);
      const block = await c.getBlock({ blockNumber: BigInt(hashBlock) });
      await dbClient.query(
        `INSERT INTO chain_cursors (chain_id, stream, last_scanned_block, last_scanned_block_hash, status, updated_at)
         VALUES ($1, $2, $3, $4, 'HEALTHY', NOW())
         ON CONFLICT (chain_id, stream)
         DO UPDATE SET last_scanned_block = $3, last_scanned_block_hash = $4, last_run_completed_at = NOW(), status = 'HEALTHY', updated_at = NOW()`,
        [CHAIN_ID, stream.name, toBlock, (block.hash as string).toLowerCase()],
      );

      await dbClient.query("COMMIT");
    } catch (err) {
      await dbClient.query("ROLLBACK");
      throw err;
    }

    console.log(`[Chain Worker] ${stream.name}: scanned ${logs.length} events, cursor advanced to ${toBlock}`);
  } finally {
    dbClient.release();
  }
}

// ── Entry Point ────────────────────────────

if (require.main === module) {
  start().catch((err) => {
    console.error("[Chain Worker] Fatal error:", err);
    process.exit(1);
  });
}
