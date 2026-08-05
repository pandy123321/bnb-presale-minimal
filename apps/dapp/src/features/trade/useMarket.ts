<script setup lang="ts">
import { ref, onUnmounted, readonly } from "vue";

/**
 * Trade market state composable.
 * - Polls trading_enabled API every 30s (pending backend endpoint).
 * - Chart instance lifecycle managed here (created only when trading_enabled=true).
 *
 * TODO: Replace polling stub with real API fetch once backend endpoint is ready:
 *   GET /api/v1/projects/pangu2/market/trading-enabled → { tradingEnabled: boolean }
 */

export function useMarket() {
  const tradingEnabled = ref(false);
  const price = ref("—");
  const change24h = ref("—");
  const high24h = ref("—");
  const low24h = ref("—");
  const volume24h = ref("—");

  let pollTimer: ReturnType<typeof setInterval> | null = null;

  /** Start polling trading_enabled. Only creates chart on first true. */
  function startPolling(): void {
    if (pollTimer) return;
    pollTimer = setInterval(async () => {
      try {
        // TODO: Replace with real API call:
        // const res = await fetch("/api/v1/projects/pangu2/market/trading-enabled");
        // tradingEnabled.value = (await res.json()).tradingEnabled;
      } catch {
        /* API not ready yet — trading stays disabled */
      }
    }, 30_000);
  }

  function stopPolling(): void { if (pollTimer) { clearInterval(pollTimer); pollTimer = null; } }

  onUnmounted(() => stopPolling());

  return {
    tradingEnabled: readonly(tradingEnabled),
    price: readonly(price),
    change24h: readonly(change24h),
    high24h: readonly(high24h),
    low24h: readonly(low24h),
    volume24h: readonly(volume24h),
    startPolling,
  };
}
</script>
