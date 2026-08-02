// ═══════════════════════════════════════════
// PANGU2 DApp — useSupport Composable
// 对接 /buybacks 和 /locker/batches API
// 硬规则: SupportPool 只读展示，无提现入口
// ═══════════════════════════════════════════

import { computed } from "vue";
import type { EnvelopeMeta, WeiAmount, BlockNumberStr, IsoTimestamp } from "@pangu2/api-types";
import { DataStatus } from "@pangu2/api-types";
import { useAsyncData, fetchGet } from "@/api";

// ── 本地类型定义（Mock API 返回的字段） ─────

export interface BuybackEntry {
  batch_id: number;
  amount_bnb_wei: string;
  tokens_raw: string;
  timestamp: string;
}

export interface LockerEntry {
  batch_id: number;
  tokens_raw: string;
  locked_until: string;
}

// ── Composable ──────────────────────────────

export function useSupport() {
  const buybacks = useAsyncData<BuybackEntry[]>(
    (signal) => fetchGet<BuybackEntry[]>("/v1/projects/pangu2/buybacks", signal),
    { immediate: true, refreshIntervalMs: 60_000 },
  );

  const locker = useAsyncData<LockerEntry[]>(
    (signal) => fetchGet<LockerEntry[]>("/v1/projects/pangu2/locker/batches", signal),
    { immediate: true, refreshIntervalMs: 60_000 },
  );

  const isLoading = computed(() => buybacks.state.value.isLoading || locker.state.value.isLoading);
  const isMockData = computed(() => buybacks.state.value.dataStatus === DataStatus.MOCK_DATA);

  function weiToDisplay(wei: string, decimals: number = 18): string {
    if (!wei || wei === "0") return "0";
    const str = wei.padStart(decimals + 1, "0");
    const intPart = str.slice(0, -decimals) || "0";
    const fracPart = str.slice(-decimals).replace(/0+$/, "");
    return fracPart ? `${intPart}.${fracPart}` : intPart;
  }

  function formatTokens(raw: string): string {
    const display = weiToDisplay(raw, 18);
    const num = parseFloat(display);
    if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M P2`;
    if (num >= 1_000) return `${Math.round(num).toLocaleString()} P2`;
    return `${num.toFixed(1)} P2`;
  }

  function formatBnb(wei: string): string {
    return `${weiToDisplay(wei, 18)} BNB`;
  }

  function timeAgo(iso: string): string {
    const diff = (Date.now() - new Date(iso).getTime()) / 1000;
    if (diff < 60) return "刚刚";
    if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
    return `${Math.floor(diff / 86400)}天前`;
  }

  return {
    buybacks,
    locker,
    isLoading,
    isMockData,
    formatTokens,
    formatBnb,
    timeAgo,
  };
}
