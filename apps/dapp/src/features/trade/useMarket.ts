import { ref, readonly, onUnmounted } from "vue";
import { fetchGet, ApiError } from "@/api";

/**
 * Trade market state composable.
 * Polls /config for chain info and /system-status for worker data.
 * Trading is enabled only when RPC=OK AND data_status=LIVE.
 */
export function useMarket() {
  const tradingEnabled = ref(false);
  const rpcStatus = ref("UNKNOWN");
  const dataStatus = ref("SYNCING");
  const blockLag = ref(0);
  const latestBlock = ref("0");
  const openAnomalies = ref(0);
  const streamStatuses = ref<Record<string, { last_scanned_block: number; status: string }>>({});

  let pollTimer: ReturnType<typeof setInterval> | null = null;
  let controller: AbortController | null = null;

  function startPolling(): void {
    if (pollTimer) return;
    const tick = async () => {
      controller = new AbortController();
      const signal = controller.signal;
      try {
        const statusRes = await fetchGet<Record<string, unknown>>(
          "/v1/projects/pangu2/system-status", signal
        );
        const s = statusRes.data;
        dataStatus.value = statusRes.meta.data_status;
        rpcStatus.value = (s.rpc_status as string) ?? "UNKNOWN";
        blockLag.value = (s.block_lag as number) ?? 0;
        latestBlock.value = (s.latest_chain_block as string) ?? "0";
        openAnomalies.value = (s.open_anomalies as number) ?? 0;
        streamStatuses.value = (s.streams as Record<string, { last_scanned_block: number; status: string }>) ?? {};
        tradingEnabled.value = rpcStatus.value === "OK" && dataStatus.value === "LIVE";
      } catch {
        dataStatus.value = "UNAVAILABLE";
        rpcStatus.value = "DOWN";
        tradingEnabled.value = false;
      }
    };
    tick();
    pollTimer = setInterval(tick, 30_000);
  }

  function stopPolling(): void {
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
    if (controller) { controller.abort(); controller = null; }
  }
  onUnmounted(() => stopPolling());

  return {
    tradingEnabled: readonly(tradingEnabled),
    rpcStatus: readonly(rpcStatus),
    dataStatus: readonly(dataStatus),
    blockLag: readonly(blockLag),
    latestBlock: readonly(latestBlock),
    openAnomalies: readonly(openAnomalies),
    streamStatuses: readonly(streamStatuses),
    startPolling,
    stopPolling,
  };
}
