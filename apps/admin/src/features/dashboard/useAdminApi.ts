// ═══════════════════════════════════════════
// PANGU2 Admin — API Composables
//
// Fetches /config, /system-status, /contracts from backend.
// Mock data phase — all responses marked MOCK_DATA.
// Updates useAppStore with live data_status on every fetch.
// ═══════════════════════════════════════════

import { ref, onMounted, onUnmounted } from "vue";
import { useAppStore } from "@/stores/useApp";
import type { EnvironmentConfig, SystemStatus, ContractInfo, Envelope } from "@pangu2/api-types";

const API_BASE = "/api/v1/projects/pangu2";
const REFRESH_INTERVAL = 30_000;

// ── Fetch helper (returns full Envelope) ─────

async function fetchEnvelope<T>(path: string): Promise<Envelope<T>> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body?.error?.message ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<Envelope<T>>;
}

// ── Admin Config ────────────────────────────

export function useAdminConfig() {
  const app = useAppStore();

  const loading = ref(false);
  const error = ref<string | null>(null);
  const project = ref("PANGU2");
  const environment = ref("LOCAL");
  const chainId = ref<number | null>(null);
  const chainName = ref("—");
  const rpcStatus = ref("—");
  const supportedNetworks = ref<number[]>([]);
  const explorerUrl = ref("https://testnet.bscscan.com");

  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetchConfig() {
    loading.value = true;
    error.value = null;
    try {
      const env = await fetchEnvelope<EnvironmentConfig>("/config");

      project.value = env.data.project;
      environment.value = env.data.environment;
      chainId.value = env.data.chain_id;
      chainName.value = env.data.chain_name;
      rpcStatus.value = env.data.rpc_status;
      supportedNetworks.value = env.data.supported_networks;

      // Sync to global app store
      app.dataStatus = env.meta.data_status;
      app.environment = env.meta.environment;
      app.chainId = env.meta.chain_id;
      app.blockNumber = env.meta.block_number;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load config";
      app.dataStatus = "UNAVAILABLE";
    } finally {
      loading.value = false;
    }
  }

  onMounted(() => {
    fetchConfig();
    timer = setInterval(fetchConfig, REFRESH_INTERVAL);
  });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  return { loading, error, project, environment, chainId, chainName, rpcStatus, supportedNetworks, explorerUrl, fetchConfig };
}

// ── Admin System Status ─────────────────────

export function useAdminSystemStatus() {
  const app = useAppStore();

  const loading = ref(false);
  const error = ref<string | null>(null);
  const latestBlock = ref("—");
  const lastScanned = ref("—");
  const blockLag = ref<number | null>(null);
  const rpcSStatus = ref("—");
  const queueStatus = ref("—");
  const openAnomalies = ref(0);

  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetchStatus() {
    loading.value = true;
    error.value = null;
    try {
      const env = await fetchEnvelope<SystemStatus>("/system-status");

      latestBlock.value = env.data.latest_chain_block;
      lastScanned.value = env.data.last_scanned_block;
      blockLag.value = env.data.block_lag;
      rpcSStatus.value = env.data.rpc_status;
      queueStatus.value = env.data.queue_status;
      openAnomalies.value = env.data.open_anomalies;

      app.dataStatus = env.meta.data_status;
      app.blockNumber = env.meta.block_number;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load status";
      app.dataStatus = "UNAVAILABLE";
    } finally {
      loading.value = false;
    }
  }

  onMounted(() => {
    fetchStatus();
    timer = setInterval(fetchStatus, REFRESH_INTERVAL);
  });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  return { loading, error, latestBlock, lastScanned, blockLag, rpcStatus: rpcSStatus, queueStatus, openAnomalies, fetchStatus };
}

// ── Admin Contracts ─────────────────────────

export function useAdminContracts() {
  const app = useAppStore();

  const loading = ref(false);
  const error = ref<string | null>(null);
  const contracts = ref<ContractInfo[]>([]);
  const total = ref(0);

  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetchContracts() {
    loading.value = true;
    error.value = null;
    try {
      const env = await fetchEnvelope<ContractInfo[]>("/contracts");

      contracts.value = env.data;
      total.value = env.data.length;

      app.dataStatus = env.meta.data_status;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load contracts";
      app.dataStatus = "UNAVAILABLE";
    } finally {
      loading.value = false;
    }
  }

  onMounted(() => {
    fetchContracts();
    timer = setInterval(fetchContracts, REFRESH_INTERVAL);
  });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  return { loading, error, contracts, total, fetchContracts };
}

// ── Admin Transactions (Mock until B05) ─────

export interface AdminTransaction {
  tx_hash: string;
  block_number: string;
  type: string;
  buyer: string;
  amount_bnb: string;
  amount_token: string;
  tax_rate: string;
  status: string;
  timestamp: string;
}

export function useAdminTransactions() {
  const loading = ref(false);
  const error = ref<string | null>(null);
  const transactions = ref<AdminTransaction[]>([]);
  const total = ref(0);
  const mode = ref<"mock" | "api">("mock"); // P2-B05 will switch to "api"

  function generateMockTransactions(): AdminTransaction[] {
    return [
      { tx_hash: "0x" + "a".repeat(64), block_number: "42815125", type: "buy",  buyer: "0x7c4Ee21d...a91f", amount_bnb: "0.10",   amount_token: "44,385.6", tax_rate: "4%",  status: "confirmed", timestamp: new Date(Date.now() - 5 * 60_000).toISOString() },
      { tx_hash: "0x" + "b".repeat(64), block_number: "42815110", type: "sell", buyer: "0x8A4241D8...b3f1", amount_bnb: "0.0214", amount_token: "10,000",   tax_rate: "4%",  status: "confirmed", timestamp: new Date(Date.now() - 2 * 3600_000).toISOString() },
      { tx_hash: "0x" + "c".repeat(64), block_number: "42810000", type: "buy",  buyer: "0xB901d24C...d2e3", amount_bnb: "1.50",   amount_token: "665,784",  tax_rate: "4%",  status: "confirmed", timestamp: new Date(Date.now() - 6 * 3600_000).toISOString() },
      { tx_hash: "0x" + "d".repeat(64), block_number: "42808000", type: "sell", buyer: "0xF203baE9...a7b9", amount_bnb: "0.05",   amount_token: "22,000",   tax_rate: "10%", status: "pending",   timestamp: new Date(Date.now() - 1 * 3600_000).toISOString() },
      { tx_hash: "0x" + "e".repeat(64), block_number: "42805000", type: "buy",  buyer: "0x1A4Ba8F3...c8d2", amount_bnb: "3.00",   amount_token: "1,331,568", tax_rate: "4%",  status: "confirmed", timestamp: new Date(Date.now() - 12 * 3600_000).toISOString() },
    ];
  }

  function fetchTransactions() {
    loading.value = true;
    error.value = null;

    if (mode.value === "mock") {
      setTimeout(() => {
        const all = generateMockTransactions();
        transactions.value = all;
        total.value = all.length;
        loading.value = false;
      }, 300);
      return;
    }

    // P2-B05: replace with real API call
    // fetchEnvelope<AdminTransaction[]>("/wallets/{address}/transactions")
  }

  onMounted(() => fetchTransactions());

  return { loading, error, transactions, total, mode, fetchTransactions };
}
