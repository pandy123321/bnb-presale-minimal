// ═══════════════════════════════════════════
// PANGU2 DApp — Staking Store (Pinia)
// ═══════════════════════════════════════════

import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { DataStatus } from "@pangu2/api-types";
import type { WeiAmount, EvmAddress, BlockNumberStr } from "@pangu2/api-types";

export type PositionStatus = "locked" | "matured" | "claimed";

export interface StakePositionSnapshot {
  positionId: number;
  amount: WeiAmount;
  lockedAt: string;
  unlockAt: string;
  claimed: boolean;
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

  // P2-002: server-time from API (avoid client clock dependency)
  const serverTimestamp = ref<number | null>(null);
  const serverTimeAvailable = ref(false);

  const positionCount = computed(() => positions.value.length);

  const totalStakedRaw = computed(() => {
    let sum = 0n;
    for (const p of positions.value) {
      if (!p.claimed) sum += BigInt(p.amount || "0");
    }
    return sum.toString() as WeiAmount;
  });

  const activePositions = computed(() => positions.value.filter((p) => !p.claimed));
  const isMockData = computed(() => dataStatus.value === DataStatus.MOCK_DATA);
  const isLive = computed(() => dataStatus.value === DataStatus.LIVE);

  function setAddress(addr: EvmAddress | null): void { address.value = addr; }
  function setPositions(items: StakePositionSnapshot[]): void { positions.value = items; }
  function setEarned(raw: WeiAmount): void { earnedRaw.value = raw; }
  function setGlobalStatus(status: StakingGlobalStatus | null): void { globalStatus.value = status; }
  function setMeta(status: DataStatus, block: BlockNumberStr | null, serverTime?: number | null): void {
    dataStatus.value = status;
    blockNumber.value = block;
    lastFetchedAt.value = Date.now();
    if (serverTime != null) { serverTimestamp.value = serverTime; serverTimeAvailable.value = true; }
  }
  function setServerTime(ts: number | null): void { serverTimestamp.value = ts; serverTimeAvailable.value = ts != null; }
  function serverNow(): number {
    return serverTimestamp.value ?? Math.floor(Date.now() / 1000);
  }
  function setLoading(v: boolean): void { loading.value = v; }
  function setError(msg: string | null): void { error.value = msg; }

  function reset(): void {
    address.value = null;
    positions.value = [];
    earnedRaw.value = "0" as WeiAmount;
    globalStatus.value = null;
    dataStatus.value = DataStatus.MOCK_DATA;
    blockNumber.value = null;
    lastFetchedAt.value = null;
    serverTimestamp.value = null;
    serverTimeAvailable.value = false;
    loading.value = false;
    error.value = null;
  }

  return {
    address, positions, earnedRaw, globalStatus,
    dataStatus, blockNumber, lastFetchedAt, serverTimestamp, serverTimeAvailable,
    loading, error,
    positionCount, totalStakedRaw, activePositions,
    isMockData, isLive,
    setAddress, setPositions, setEarned, setGlobalStatus,
    setMeta, setServerTime, serverNow,
    setLoading, setError, reset,
  };
});
