import { ref, readonly, onUnmounted } from "vue";
import { fetchGet } from "@/api";

const MAX_TRADE_LAG = 30;

export function useMarket() {
  const tradingEnabled = ref(false);
  const rpcStatus = ref("UNKNOWN");
  const dataStatus = ref("SYNCING");
  const blockLag = ref<number | null>(null);
  const latestBlock = ref("0");
  const openAnomalies = ref(0);
  const streamStatuses = ref<Record<string, { last_scanned_block: number; status: string }>>({});

  let pollTimer: ReturnType<typeof setInterval> | null = null;
  let controller: AbortController | null = null;
  let requestId = 0;

  function startPolling(): void {
    if (pollTimer) return;
    const tick = async () => {
      if (controller) controller.abort();
      controller = new AbortController();
      const signal = controller.signal;
      const thisId = ++requestId;
      try {
        const statusRes = await fetchGet<Record<string, unknown>>(
          "/v1/projects/pangu2/system-status", signal,
        );
        if (thisId !== requestId) return;

        const s = statusRes.data;
        dataStatus.value = statusRes.meta.data_status;
        rpcStatus.value = (s.rpc_status as string) ?? "UNKNOWN";
        blockLag.value = typeof s.block_lag === "number" ? (s.block_lag as number) : null;
        latestBlock.value = (s.latest_chain_block as string) ?? "0";
        openAnomalies.value = (s.open_anomalies as number) ?? 0;
        streamStatuses.value = (s.streams as Record<string, { last_scanned_block: number; status: string }>) ?? {};

        const lag = blockLag.value;
        tradingEnabled.value =
          rpcStatus.value === "OK" &&
          dataStatus.value === "LIVE" &&
          lag !== null &&
          lag <= MAX_TRADE_LAG;
      } catch {
        if (thisId !== requestId) return;
        dataStatus.value = "UNAVAILABLE";
        rpcStatus.value = "DOWN";
        blockLag.value = null;
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
