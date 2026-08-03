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

  function fetchTransactions() {
    loading.value = true;
    error.value = null;

    // Fetch real transactions from API. Falls back to empty on failure.
    fetch(`${ADMIN_API}/wallets/0x0000000000000000000000000000000000000000/transactions`)
      .then(r => r.json())
      .then(body => {
        if (body?.data?.length) {
          transactions.value = body.data;
          total.value = body.meta?.total ?? body.data.length;
        } else {
          transactions.value = [];
          total.value = 0;
        }
        loading.value = false;
      })
      .catch(e => { error.value = e.message; loading.value = false; });
  }

  onMounted(() => fetchTransactions());

  return { loading, error, transactions, total, fetchTransactions };
}
