import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { DataStatus } from "@pangu2/api-types";

export const DATA_STATUS_LABELS: Record<string, string> = {
  SYNCING: "Syncing",
  LIVE: "Live",
  STALE: "Stale (data may be outdated)",
  DEGRADED: "Degraded (connection issues)",
  UNAVAILABLE: "Unavailable (cannot reach backend)",
};

export const DATA_STATUS_COLORS: Record<string, string> = {
  SYNCING: "#6aa9ff",
  LIVE: "#43cf8b",
  STALE: "#f3a34b",
  DEGRADED: "#ff747d",
  UNAVAILABLE: "#ff747d",
};

export const useAppStore = defineStore("app", () => {
  const dataStatus = ref<string>("SYNCING");
  const environment = ref("LOCAL");
  const chainId = ref<number>(31337);
  const blockNumber = ref<string | null>(null);

  const statusLabel = computed(() => DATA_STATUS_LABELS[dataStatus.value] ?? dataStatus.value);
  const statusColor = computed(() => DATA_STATUS_COLORS[dataStatus.value] ?? "#9298a5");
  const isLive = computed(() => dataStatus.value === "LIVE");
  const isDegraded = computed(() => dataStatus.value === "DEGRADED" || dataStatus.value === "UNAVAILABLE");

  return { dataStatus, environment, chainId, blockNumber, statusLabel, statusColor, isLive, isDegraded };
});
