<script setup lang="ts">
import { ref, computed, onUnmounted } from "vue";
import { type CreateChartOptions, type IChartApi } from "lightweight-charts";

/** Trading not yet enabled → no chart, no countdown. Polling checks every 30s. */
let pollTimer: ReturnType<typeof setInterval> | null = null;
let chartInstance: IChartApi | null = null;

const tradingEnabled = ref(false);
const enablePolling = ref(true);
const price = ref("—");
const change24h = ref("—");
const high24h = ref("—");
const low24h = ref("—");
const volume24h = ref("—");

/** Start polling trading_enabled API. Only creates chart on first true. */
function startPolling(): void {
  pollTimer = setInterval(async () => {
    try {
      // Poll API for trading_enabled flag (implementation pending backend)
      // For now: mock — never enables until real API is ready
      if (!enablePolling.value) return;
    } catch { /* ignore poll errors */ }
  }, 30_000);
}

/** Create lightweight-charts instance (only called when trading_enabled=true). */
function createChart(container: HTMLElement): void {
  // Chart creation deferred to when trading_enabled becomes true
  // placeholder: trading not yet activated
}

function destroyChart(): void {
  chartInstance?.remove(); chartInstance = null;
}

onUnmounted(() => { if (pollTimer) clearInterval(pollTimer); destroyChart(); });

/** Public API */
export function useMarket() {
  return { tradingEnabled, price, change24h, high24h, low24h, volume24h, startPolling, enablePolling };
}
</script>
