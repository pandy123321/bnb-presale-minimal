// ═══════════════════════════════════════════
// PANGU2 DApp — useProfile Composable
// 对接 /wallets/{address}/summary API
// 显示余额、成本、税率和排名
// ═══════════════════════════════════════════

import { computed, watch, type Ref } from "vue";
import type { WalletSummary } from "@pangu2/api-types";
import { DataStatus } from "@pangu2/api-types";
import { useAsyncData, fetchGet } from "@/api";

export function useProfile(address: Ref<string | null>) {
  const summary = useAsyncData<WalletSummary>(
    (signal) => {
      if (!address.value) throw new Error("no_address");
      return fetchGet<WalletSummary>(
        `/v1/projects/pangu2/wallets/${address.value}/summary`,
        signal,
      );
    },
    { immediate: false },
  );

  // ── 钱包连接/断开时自动获取 ─────────
  watch(address, (newAddr) => {
    if (newAddr) {
      summary.execute();
    } else {
      summary.cancel();
    }
  });

  // ── 派生 ────────────────────────────
  const isLoading = computed(() => summary.state.value.isLoading);
  const isMockData = computed(() => summary.state.value.dataStatus === DataStatus.MOCK_DATA);
  const hasData = computed(() => !!summary.state.value.data);
  const rankTier = computed(() => {
    const rank = summary.state.value.data?.rank;
    if (!rank) return null;
    if (rank <= 10) return { name: "Tier 1", share: 35 };
    if (rank <= 30) return { name: "Tier 2", share: 25 };
    if (rank <= 60) return { name: "Tier 3", share: 25 };
    if (rank <= 100) return { name: "Tier 4", share: 15 };
    return null;
  });

  function weiToDisplay(wei: string, decimals: number = 18): string {
    if (!wei || wei === "0") return "0";
    const str = wei.padStart(decimals + 1, "0");
    const intPart = str.slice(0, -decimals) || "0";
    const fracPart = str.slice(-decimals).replace(/0+$/, "");
    return fracPart ? `${intPart}.${fracPart}` : intPart;
  }

  function formatTokenBalance(raw: string): string {
    const display = weiToDisplay(raw, 18);
    const num = parseFloat(display);
    if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
    return Math.round(num).toLocaleString();
  }

  return {
    summary,
    isLoading,
    isMockData,
    hasData,
    rankTier,
    formatTokenBalance,
  };
}
