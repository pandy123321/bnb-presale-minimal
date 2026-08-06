import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { DataStatus, isLive } from "@pangu2/api-types";
import type { DataStatus as DataStatusType, EnvelopeMeta } from "@pangu2/api-types";

const STALE_THRESHOLD_MS = 120_000;
const DEGRADED_THRESHOLD_MS = 600_000;
const FRESHNESS_CHECK_INTERVAL_MS = 15_000;

export const STATUS_LABELS: Record<DataStatusType, string> = {
  [DataStatus.MOCK_DATA]: "Mock Data",
  [DataStatus.SYNCING]: "Syncing",
  [DataStatus.LIVE]: "Live",
  [DataStatus.STALE]: "Stale",
  [DataStatus.DEGRADED]: "Degraded",
  [DataStatus.UNAVAILABLE]: "Unavailable",
};

export const STATUS_COLORS: Record<DataStatusType, string> = {
  [DataStatus.MOCK_DATA]: "#f3a34b",
  [DataStatus.SYNCING]: "var(--blue)",
  [DataStatus.LIVE]: "var(--green)",
  [DataStatus.STALE]: "#f3a34b",
  [DataStatus.DEGRADED]: "var(--red)",
  [DataStatus.UNAVAILABLE]: "var(--red)",
};

export const useDataStatusStore = defineStore("dataStatus", () => {
  const status = ref<DataStatusType>(DataStatus.SYNCING);
  const blockNumber = ref<string | null>(null);
  const schemaVersion = ref<string>("1.0.0");
  const lastUpdatedAt = ref<number>(0);
  const environment = ref<string>("LOCAL");
  const chainId = ref<number>(31337);
  let freshnessTimer: ReturnType<typeof setInterval> | null = null;

  const isFresh = computed(() => {
    if (!isLive(status.value)) return false;
    return Date.now() - lastUpdatedAt.value < STALE_THRESHOLD_MS;
  });

  const statusLabel = computed(() => STATUS_LABELS[status.value] ?? status.value);
  const statusColor = computed(() => STATUS_COLORS[status.value] ?? "var(--muted)");
  const ageMs = computed(() => lastUpdatedAt.value === 0 ? 0 : Date.now() - lastUpdatedAt.value);

  const ageFormatted = computed(() => {
    const ms = ageMs.value;
    if (ms < 1000) return "just now";
    const sec = Math.floor(ms / 1000);
    if (sec < 60) return `${sec}s`;
    const min = Math.floor(sec / 60);
    const remainSec = sec % 60;
    return remainSec > 0 ? `${min}m ${remainSec}s` : `${min}m`;
  });

  const isDegraded = computed(() =>
    status.value === DataStatus.DEGRADED || status.value === DataStatus.UNAVAILABLE
  );

  const isMock = computed(() => status.value === DataStatus.MOCK_DATA);

  function recordSuccess(meta: EnvelopeMeta): void {
    status.value = meta.data_status;
    blockNumber.value = meta.block_number;
    environment.value = meta.environment;
    chainId.value = meta.chain_id;
    lastUpdatedAt.value = Date.now();
  }

  function recordError(): void {
    status.value = DataStatus.UNAVAILABLE;
  }

  function evaluateFreshness(): void {
    if (status.value !== DataStatus.LIVE) return;
    const age = Date.now() - lastUpdatedAt.value;
    if (age >= DEGRADED_THRESHOLD_MS) status.value = DataStatus.DEGRADED;
    else if (age >= STALE_THRESHOLD_MS) status.value = DataStatus.STALE;
  }

  function startFreshnessTimer(): void {
    if (freshnessTimer) return;
    freshnessTimer = setInterval(evaluateFreshness, FRESHNESS_CHECK_INTERVAL_MS);
  }

  function stopFreshnessTimer(): void {
    if (freshnessTimer) { clearInterval(freshnessTimer); freshnessTimer = null; }
  }

  startFreshnessTimer();

  return {
    status, blockNumber, schemaVersion, lastUpdatedAt, environment, chainId,
    isFresh, isDegraded, statusLabel, statusColor, ageMs, ageFormatted,
    recordSuccess, recordError, evaluateFreshness,
    startFreshnessTimer, stopFreshnessTimer,
  };
});
