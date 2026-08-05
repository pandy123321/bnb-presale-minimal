// PANGU2 Chain Worker — Event Scanner

import {
  createPublicClient, http, type PublicClient,
  decodeEventLog,
} from "viem";
import { loadRequiredAbis, type AbiArtifact } from "../abi/loader";
import type { Abi } from "viem";
import {
  getPool, getCursor, upsertCursor,
  acquireLease, releaseLease, insertRawEvents,
  checkLeaseValid,
  type RawEventRow,
} from "../db/client";
import { toJsonSafe } from "../utils/json-safe";
import {
  CHAIN_ID, RPC_URL, SCAN_BATCH_SIZE, CONFIRMATION_BLOCKS,
  SCAN_INTERVAL_SECONDS, WORKER_ID, LEASE_TTL_SECONDS, DEPLOYMENT_BLOCK,
  TRADE_ROUTER_ADDRESS, DIVIDEND_DISTRIBUTOR_ADDRESS, rpcLogLabel,
} from "../config";

// ── ABI load ─────────────────────────────────
const requiredAbis: Map<string, AbiArtifact> = loadRequiredAbis();
const tradeAbi = requiredAbis.get("Pangu2TradeRouter");
const dividendAbi = requiredAbis.get("DividendDistributor");
if (!tradeAbi || !dividendAbi) {
  console.error("[Scanner] FATAL: Required ABIs not found");
  process.exit(1);
}

interface ScanStream {
  name: string; contractAddress: `0x${string}`; abi: Abi; startBlock: number;
}

const STREAMS: ScanStream[] = [
  { name: "TRADE_EVENTS", contractAddress: TRADE_ROUTER_ADDRESS as `0x${string}`, abi: tradeAbi.abi as Abi, startBlock: DEPLOYMENT_BLOCK },
  { name: "DIVIDEND_EVENTS", contractAddress: DIVIDEND_DISTRIBUTOR_ADDRESS as `0x${string}`, abi: dividendAbi.abi as Abi, startBlock: DEPLOYMENT_BLOCK },
];

let rpc: PublicClient | null = null;
function getRpc(): PublicClient {
  if (!rpc) rpc = createPublicClient({ transport: http(RPC_URL) });
  return rpc;
}

export async function start(): Promise<void> {
  await validateEnvironment();
  console.log(`[Scanner] Chain ${CHAIN_ID} RPC ${rpcLogLabel()}`);
  await scanAllStreams();
  setInterval(() => scanAllStreams().catch(e => console.error("[Scanner]", e)), SCAN_INTERVAL_SECONDS * 1000);
}

async function validateEnvironment(): Promise<void> {
  const c = getRpc();
  if (await c.getChainId() !== CHAIN_ID) { console.error("[Scanner] FATAL: chain mismatch"); process.exit(1); }
  for (const s of STREAMS) {
    const code = await c.getBytecode({ address: s.contractAddress });
    if (!code || code === "0x") { console.error(`[Scanner] FATAL: ${s.name} no bytecode`); process.exit(1); }
  }
  if (DEPLOYMENT_BLOCK > Number(await c.getBlockNumber())) { console.error("[Scanner] FATAL: deployment > latest"); process.exit(1); }
}

async function scanAllStreams(): Promise<void> {
  for (const stream of STREAMS) {
    const { leased, leaseGeneration } = await acquireLease(CHAIN_ID, stream.name, WORKER_ID, LEASE_TTL_SECONDS);
    if (!leased) continue;
    try { await scanStream(stream, leaseGeneration); }
    finally { await releaseLease(CHAIN_ID, stream.name, WORKER_ID); }
  }
}

async function scanStream(stream: ScanStream, leaseGeneration: number): Promise<void> {
  const c = getRpc();
  const pool = getPool();
  const db = await pool.connect();

  try {
    await db.query("BEGIN");

    // Validate lease is still current before any writes
    const valid = await checkLeaseValid(db, CHAIN_ID, stream.name, leaseGeneration, WORKER_ID);
    if (!valid) {
      console.warn(`[Scanner] ${stream.name}: lease expired/invalid (gen=${leaseGeneration}), aborting`);
      await db.query("ROLLBACK");
      return;
    }

    const cursor = await getCursor(db, CHAIN_ID, stream.name);
    const fromBlock = cursor ? cursor.last_scanned_block + 1 : Math.max(1, parseInt(process.env.START_BLOCK ?? "0") + 1);
    const latest = Number(await c.getBlockNumber());
    const safeLatest = latest - CONFIRMATION_BLOCKS;
    const toBlock = Math.min(fromBlock + SCAN_BATCH_SIZE - 1, safeLatest);

    if (fromBlock > safeLatest) { await db.query("ROLLBACK"); return; }

    const logs = await c.getLogs({ address: stream.contractAddress, fromBlock: BigInt(fromBlock), toBlock: BigInt(toBlock) });

    const rawEvents: RawEventRow[] = [];
    for (const log of logs) {
      const block = await c.getBlock({ blockNumber: log.blockNumber! });
      let eventName: string | null = log.topics[0] ?? null;
      let decoded: Record<string, unknown> = {};
      try {
        const d = decodeEventLog({ abi: stream.abi, data: log.data as `0x${string}`, topics: log.topics as [`0x${string}`, ...`0x${string}`[]] });
        eventName = d.eventName ?? eventName;
        decoded = toJsonSafe(d.args) as Record<string, unknown>;
        if (!decoded || Object.keys(decoded).length === 0) decoded = { topics: log.topics, data: log.data };
      } catch { decoded = { topics: log.topics, data: log.data } as unknown as Record<string, unknown>; eventName = null; }
      rawEvents.push({
        chain_id: CHAIN_ID, contract_address: (log.address as string).toLowerCase(), event_name: eventName,
        transaction_hash: (log.transactionHash as string).toLowerCase(), log_index: log.logIndex ?? 0,
        block_number: Number(log.blockNumber), block_hash: (log.blockHash as string).toLowerCase(),
        transaction_index: log.transactionIndex ?? null,
        block_timestamp: new Date(Number(block.timestamp) * 1000).toISOString(),
        decoded_data: decoded, topics: log.topics as string[], raw_data: log.data, status: "PENDING_CONFIRMATION",
      });
    }

    // Always get real toBlock hash (even empty intervals need it for reorg detection)
    const toBlockObj = await c.getBlock({ blockNumber: BigInt(toBlock) });
    const lastBlockHash = (toBlockObj.hash as string).toLowerCase();

    if (rawEvents.length > 0) await insertRawEvents(db, rawEvents);
    const written = await upsertCursor(db, CHAIN_ID, stream.name, toBlock, lastBlockHash, "SYNCED", leaseGeneration);
    if (!written) {
      console.warn(`[Scanner] ${stream.name}: cursor update rejected — lease stale (gen=${leaseGeneration})`);
      await db.query("ROLLBACK");
      return;
    }
    await db.query("COMMIT");

    console.log(`[Scanner] ${stream.name}: ${rawEvents.length} events [${fromBlock}-${toBlock}] hash=${lastBlockHash.slice(0,10)} gen=${leaseGeneration}`);
  } catch (e) {
    await db.query("ROLLBACK").catch(() => {});
    throw e;
  } finally { db.release(); }
}
