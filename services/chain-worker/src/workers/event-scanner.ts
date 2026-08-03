// PANGU2 Chain Worker — Event Scanner

import {
  createPublicClient,
  http,
  type PublicClient,
  decodeEventLog,
} from "viem";
import { loadRequiredAbis, type AbiArtifact } from "../abi/loader";
import type { Abi } from "viem";
import {
  getPool, getCursor, upsertCursor,
  acquireLease, releaseLease, insertRawEvents,
  type RawEventRow,
} from "../db/client";
import { toJsonSafe } from "../utils/json-safe";
import {
  CHAIN_ID, RPC_URL, SCAN_BATCH_SIZE, CONFIRMATION_BLOCKS,
  SCAN_INTERVAL_SECONDS, WORKER_ID, LEASE_TTL_SECONDS, DEPLOYMENT_BLOCK,
  TRADE_ROUTER_ADDRESS, DIVIDEND_DISTRIBUTOR_ADDRESS, rpcLogLabel,
} from "../config";

// ── ABI load (fail-fast) ──────────────────────

const requiredAbis: Map<string, AbiArtifact> = loadRequiredAbis();
const tradeAbi = requiredAbis.get("Pangu2TradeRouter");
const dividendAbi = requiredAbis.get("DividendDistributor");

if (!tradeAbi || !dividendAbi) {
  console.error("[Chain Worker] FATAL: Required ABIs not found");
  process.exit(1);
}

// ── Stream Definitions ─────────────────────────

interface ScanStream {
  name: string;
  contractAddress: `0x${string}`;
  abi: Abi;
  startBlock: number;
}

const STREAMS: ScanStream[] = [
  {
    name: "TRADE_EVENTS",
    contractAddress: TRADE_ROUTER_ADDRESS as `0x${string}`,
    abi: tradeAbi.abi as Abi,
    startBlock: DEPLOYMENT_BLOCK,
  },
  {
    name: "DIVIDEND_EVENTS",
    contractAddress: DIVIDEND_DISTRIBUTOR_ADDRESS as `0x${string}`,
    abi: dividendAbi.abi as Abi,
    startBlock: DEPLOYMENT_BLOCK,
  },
];

// ── RPC ────────────────────────────────────────

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) });
  return rpc;
}

// ── Start ──────────────────────────────────────

export async function start(): Promise<void> {
  // Startup validation
  await validateEnvironment();

  console.log("[Chain Worker] Starting...");
  console.log(`  Chain ID: ${CHAIN_ID}`);
  console.log(`  RPC: ${rpcLogLabel()}`);
  console.log(`  TradeRouter: ${TRADE_ROUTER_ADDRESS}`);
  console.log(`  DividendDistributor: ${DIVIDEND_DISTRIBUTOR_ADDRESS}`);
  console.log(`  Batch size: ${SCAN_BATCH_SIZE}`);
  console.log(`  Worker ID: ${WORKER_ID}`);

  await scanAllStreams();
  setInterval(() => scanAllStreams().catch(e => console.error("[Chain Worker] scan error", e)), SCAN_INTERVAL_SECONDS * 1000);
}

async function validateEnvironment(): Promise<void> {
  const c = getRpc();

  // Verify chain ID
  const chainId = await c.getChainId();
  if (chainId !== CHAIN_ID) {
    console.error(`[Chain Worker] FATAL: RPC chain ${chainId} != config ${CHAIN_ID}`);
    process.exit(1);
  }

  // Verify contract addresses
  for (const s of STREAMS) {
    const code = await c.getBytecode({ address: s.contractAddress });
    if (!code || code === "0x") {
      console.error(`[Chain Worker] FATAL: ${s.name} at ${s.contractAddress} has no bytecode`);
      process.exit(1);
    }
  }

  // Verify deployment block
  const latest = Number(await c.getBlockNumber());
  if (DEPLOYMENT_BLOCK > latest) {
    console.error(`[Chain Worker] FATAL: DEPLOYMENT_BLOCK ${DEPLOYMENT_BLOCK} > latest ${latest}`);
    process.exit(1);
  }
}

async function scanAllStreams(): Promise<void> {
  for (const stream of STREAMS) {
    const leased = await acquireLease(CHAIN_ID, stream.name, WORKER_ID, LEASE_TTL_SECONDS);
    if (!leased) continue;
    try { await scanStream(stream); }
    finally { await releaseLease(CHAIN_ID, stream.name); }
  }
}

async function scanStream(stream: ScanStream): Promise<void> {
  const c = getRpc();
  const cursor = await getCursor(CHAIN_ID, stream.name);
  const fromBlock = cursor.last_scanned_block + 1;
  const latest = Number(await c.getBlockNumber());
  const safeLatest = latest - CONFIRMATION_BLOCKS;
  const toBlock = Math.min(fromBlock + SCAN_BATCH_SIZE - 1, safeLatest);

  if (fromBlock > safeLatest) return;

  const logs = await c.getLogs({
    address: stream.contractAddress,
    fromBlock: BigInt(fromBlock),
    toBlock: BigInt(toBlock),
  });

  if (logs.length === 0) {
    await upsertCursor(CHAIN_ID, stream.name, toBlock, "", "SYNCED");
    return;
  }

  const rawEvents: RawEventRow[] = [];
  for (const log of logs) {
    const block = await c.getBlock({ blockNumber: log.blockNumber! });

    let eventName: string | null = log.topics[0] ?? null;
    let decoded: Record<string, unknown> = {};

    try {
      const decodedLog = decodeEventLog({
        abi: stream.abi,
        data: log.data as `0x${string}`,
        topics: log.topics as `0x${string}`[],
      });
      eventName = decodedLog.eventName ?? eventName;
      decoded = toJsonSafe(decodedLog.args) as Record<string, unknown>;
      if (!decoded || Object.keys(decoded).length === 0) {
        decoded = { topics: log.topics, data: log.data };
      }
    } catch {
      // Unknown event or ABI mismatch — keep as raw
      decoded = { topics: log.topics as unknown[] as Record<string, unknown>, data: log.data };
      eventName = null;
    }

    rawEvents.push({
      chain_id: CHAIN_ID,
      contract_address: (log.address as string).toLowerCase(),
      event_name: eventName,
      transaction_hash: (log.transactionHash as string).toLowerCase(),
      log_index: log.logIndex ?? 0,
      block_number: Number(log.blockNumber),
      block_hash: (log.blockHash as string).toLowerCase(),
      transaction_index: log.transactionIndex ?? null,
      block_timestamp: new Date(Number(block.timestamp) * 1000).toISOString(),
      decoded_data: decoded,
      topics: log.topics as string[],
      raw_data: log.data,
      status: "PENDING_CONFIRMATION",
    });
  }

  const db = getPool();
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    await insertRawEvents(client, rawEvents);
    const lastBlockHash = rawEvents[rawEvents.length - 1].block_hash;
    await upsertCursor(CHAIN_ID, stream.name, toBlock, lastBlockHash, "SYNCED");
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK").catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}
