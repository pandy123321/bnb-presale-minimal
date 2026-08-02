// ═══════════════════════════════════════════
// PANGU2 DApp — Global Data Store
// Manages data_status, freshness, and system-wide state.
// All UI components MUST use this for data status display.
// ═══════════════════════════════════════════

import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { DataStatus } from "@pangu2/api-types";
import { systemApi } from "@/api/client";
import type { EnvironmentConfig, SystemStatus, ContractInfo } from "@pangu2/api-types";

export const useDataStore = defineStore("data", () => {
  // ── State ──

  const dataStatus = ref<DataStatus>(DataStatus.MOCK_DATA);
  const blockNumber = ref<string | null>(null);
  const config = ref<EnvironmentConfig | null>(null);
  const systemStatus = ref<SystemStatus | null>(null);
  const contracts = ref<ContractInfo[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // ── Computed ──

  const isLive = computed(() => dataStatus.value === DataStatus.LIVE);
  const isMocked = computed(() => dataStatus.value === DataStatus.MOCK_DATA);
  const isDegraded = computed(() => dataStatus.value === DataStatus.DEGRADED);
  const isStale = computed(() => dataStatus.value === DataStatus.STALE);
  const isUnavailable = computed(() => dataStatus.value === DataStatus.UNAVAILABLE);
  const isSyncing = computed(() => dataStatus.value === DataStatus.SYNCING);
  const needsWarning = computed(() => !isLive.value && !isSyncing.value);

  // ── Actions ──

  async function fetchConfig(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const env = await systemApi.getConfig();
      config.value = env.data;
      dataStatus.value = env.meta.data_status;
      blockNumber.value = env.meta.block_number;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Failed to load config";
      error.value = msg;
      dataStatus.value = DataStatus.UNAVAILABLE;
    } finally {
      loading.value = false;
    }
  }

  async function fetchSystemStatus(): Promise<void> {
    try {
      const env = await systemApi.getSystemStatus();
      systemStatus.value = env.data;
      dataStatus.value = env.meta.data_status;
      blockNumber.value = env.meta.block_number;
    } catch {
      dataStatus.value = DataStatus.DEGRADED;
    }
  }

  async function fetchContracts(): Promise<void> {
    try {
      const env = await systemApi.getContracts();
      contracts.value = env.data;
    } catch {
      // Non-critical
    }
  }

  /** Load all system data on app start. */
  async function init(): Promise<void> {
    await Promise.allSettled([
      fetchConfig(),
      fetchSystemStatus(),
      fetchContracts(),
    ]);
  }

  return {
    dataStatus,
    blockNumber,
    config,
    systemStatus,
    contracts,
    loading,
    error,
    isLive,
    isMocked,
    isDegraded,
    isStale,
    isUnavailable,
    isSyncing,
    needsWarning,
    fetchConfig,
    fetchSystemStatus,
    fetchContracts,
    init,
  };
});
