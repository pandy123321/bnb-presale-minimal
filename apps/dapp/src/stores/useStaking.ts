// ═══════════════════════════════════════════
// PANGU2 DApp — Staking Store (Pinia)
// 缓存仓位列表 + 收益 + 全局状态
// 金额字段全部为十进制整数字符串（WeiAmount）
// ═══════════════════════════════════════════

import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { DataStatus } from "@pangu2/api-types";
import type { WeiAmount, EvmAddress, BlockNumberStr } from "@pangu2/api-types";

/** 仓位状态（前端派生） */
export type PositionStatus = "locked" | "matured" | "claimed";

/** API / 合约仓位快照 */
export interface StakePositionSnapshot {
  positionId: number;
  amount: WeiAmount;
  lockedAt: string;
  unlockAt: string;
  claimed: boolean;
  /** 按仓位本金占比分摊的账户收益（估算） */
  earnedEstimate: WeiAmount;
  status: PositionStatus;
  remainingDays: number;
}

export interface StakingGlobalStatus {
  totalStaked: WeiAmount;
  rewardRate: WeiAmount;
  periodFinish: string;
  availableRewardReserve: WeiAmount;
}

export const useStakingStore = defineStore("staking", () => {
  const address = ref<EvmAddress | null>(null);
  const positions = ref<StakePositionSnapshot[]>([]);
  const earnedRaw = ref<WeiAmount>("0" as WeiAmount);
  const globalStatus = ref<StakingGlobalStatus | null>(null);
  const dataStatus = ref<DataStatus>(DataStatus.MOCK_DATA);
  const blockNumber = ref<BlockNumberStr | null>(null);
  const lastFetchedAt = ref<number | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const positionCount = computed(() => positions.value.length);

  const totalStakedRaw = computed(() => {
    let sum = 0n;
    for (const p of positions.value) {
      if (!p.claimed) sum += BigInt(p.amount || "0");
    }
    return sum.toString() as WeiAmount;
  });

  const activePositions = computed(() =>
    positions.value.filter((p) => !p.claimed),
  );

  const isMockData = computed(() => dataStatus.value === DataStatus.MOCK_DATA);
  const isLive = computed(() => dataStatus.value === DataStatus.LIVE);

  function setAddress(addr: EvmAddress | null): void {
    address.value = addr;
  }

  function setPositions(items: StakePositionSnapshot[]): void {
    positions.value = items;
  }

  function setEarned(raw: WeiAmount): void {
    earnedRaw.value = raw;
  }

  function setGlobalStatus(status: StakingGlobalStatus | null): void {
    globalStatus.value = status;
  }

  function setMeta(
    status: DataStatus,
    block: BlockNumberStr | null,
  ): void {
    dataStatus.value = status;
    blockNumber.value = block;
    lastFetchedAt.value = Date.now();
  }

  function setLoading(v: boolean): void {
    loading.value = v;
  }

  function setError(msg: string | null): void {
    error.value = msg;
  }

  function reset(): void {
    address.value = null;
    positions.value = [];
    earnedRaw.value = "0" as WeiAmount;
    globalStatus.value = null;
    dataStatus.value = DataStatus.MOCK_DATA;
    blockNumber.value = null;
    lastFetchedAt.value = null;
    loading.value = false;
    error.value = null;
  }

  return {
    address,
    positions,
    earnedRaw,
    globalStatus,
    dataStatus,
    blockNumber,
    lastFetchedAt,
    loading,
    error,
    positionCount,
    totalStakedRaw,
    activePositions,
    isMockData,
    isLive,
    setAddress,
    setPositions,
    setEarned,
    setGlobalStatus,
    setMeta,
    setLoading,
    setError,
    reset,
  };
});
