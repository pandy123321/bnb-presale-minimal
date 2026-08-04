// ═══════════════════════════════════════════
// PANGU2 Admin — Staking API Composable
//
// Endpoints:
//   GET  /admin-api/v1/projects/pangu2/staking/coverage
//   POST /admin-api/v1/projects/pangu2/staking/fund-rewards
//   POST /admin-api/v1/projects/pangu2/staking/set-reward-rate
//   GET  /api/v1/projects/pangu2/staking/status
//   GET  /api/v1/projects/pangu2/staking/positions?address=0x...
//
// 硬规则:
//   - Fund + SetRate 二次确认
//   - 所有金额整数字符串，禁止 float
//   - MOCK_DATA 显式标记
// ═══════════════════════════════════════════

import { ref, onMounted } from "vue";
import { adminFetch } from "@/api/adminFetch";
import type { Envelope } from "@pangu2/api-types";

const ADMIN_API = "/admin-api/v1/projects/pangu2";
const PUBLIC_API = "/api/v1/projects/pangu2";
const REFRESH_INTERVAL = 30_000;

// ── Types ───────────────────────────────────

export interface StakingCoverage {
  totalStaked: string;
  totalStakedFormatted: string;
  rewardRate: string;
  rewardRateFormatted: string;
  rewardReserveBalance: string;
  rewardReserveFormatted: string;
  coverageRatio: string;
  coverageRatioPercent: string;
  dataStatus: string;
}

export interface StakingStatus {
  rewardToken: string;
  stakingToken: string;
  rewardRate: string;
  lastUpdateBlock: string;
  periodFinish: string;
  totalSupply: string;
  totalSupplyFormatted: string;
  dataStatus: string;
}

export interface StakingPosition {
  positionId: string;
  owner: string;
  amount: string;
  amountFormatted: string;
  lockedAt: string;
  unlockAt: string;
  status: "LOCKED" | "UNLOCKING" | "UNLOCKED" | "WITHDRAWN";
  estimatedReward: string;
  estimatedRewardFormatted: string;
  rewardDebt: string;
}

export interface FundRewardsRequest {
  amount: string;
  token: string;
}

export interface SetRewardRateRequest {
  rewardRate: string;
}

// ── Composable ──────────────────────────────

export function useAdminStaking() {
  // State
  const loading = ref(false);
  const error = ref<string | null>(null);
  const dataStatus = ref("MOCK_DATA");

  // Coverage
  const coverage = ref<StakingCoverage | null>(null);
  const coverageLoading = ref(false);

  // Status
  const status = ref<StakingStatus | null>(null);
  const statusLoading = ref(false);

  // Positions
  const positions = ref<StakingPosition[]>([]);
  const positionsLoading = ref(false);
  const searchAddress = ref("");

  // Admin operations
  const fundLoading = ref(false);
  const fundError = ref<string | null>(null);
  const fundSuccess = ref<string | null>(null);
  const rateLoading = ref(false);
  const rateError = ref<string | null>(null);
  const rateSuccess = ref<string | null>(null);

  // Confirm modal
  const confirmModal = ref<{ type: "fund" | "rate"; title: string; summary: string; action: () => Promise<void> } | null>(null);

  // ── Fetch Coverage ─────────────────────────
  async function fetchCoverage() {
    coverageLoading.value = true;
    try {
      const res = await fetch(`${ADMIN_API}/staking/coverage`, { credentials: "include" });
      const body: Envelope<StakingCoverage> = await res.json();
      if (body.error) throw new Error(body.error.message);
      coverage.value = body.data;
      dataStatus.value = body.meta.data_status;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load coverage";
    } finally {
      coverageLoading.value = false;
    }
  }

  // ── Fetch Status ──────────────────────────
  async function fetchStatus() {
    statusLoading.value = true;
    try {
      const res = await fetch(`${PUBLIC_API}/staking/status`);
      const body: Envelope<StakingStatus> = await res.json();
      if (body.error) throw new Error(body.error.message);
      status.value = body.data;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load status";
    } finally {
      statusLoading.value = false;
    }
  }

  // ── Fetch Positions ───────────────────────
  async function fetchPositions(address?: string) {
    positionsLoading.value = true;
    const addr = address ?? searchAddress.value;
    if (!addr || addr.length < 42) {
      positions.value = [];
      positionsLoading.value = false;
      return;
    }
    try {
      const res = await fetch(`${PUBLIC_API}/staking/positions?address=${addr}`);
      const body: Envelope<StakingPosition[]> = await res.json();
      if (body.error) throw new Error(body.error.message);
      positions.value = Array.isArray(body.data) ? body.data : [];
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed to load positions";
      positions.value = [];
    } finally {
      positionsLoading.value = false;
    }
  }

  function searchPositions(addr: string) {
    searchAddress.value = addr.trim();
    fetchPositions(searchAddress.value);
  }

  // ── Admin: Fund Rewards ───────────────────
  function requestFundRewards(amount: string) {
    if (!amount || amount === "0") {
      fundError.value = "请输入有效金额";
      return;
    }
    confirmModal.value = {
      type: "fund",
      title: "确认充值奖励池",
      summary: `金额: ${amount} PANGU2\n操作: fund-rewards\n此操作需要 SUPER_ADMIN 权限`,
      action: async () => {
        fundLoading.value = true;
        fundError.value = null;
        fundSuccess.value = null;
        try {
          const res = await adminFetch("/staking/fund-rewards", {
            method: "POST",
            body: JSON.stringify({ amount, token: "PANGU2" } satisfies FundRewardsRequest),
          });
          const body = await res.json();
          if (!res.ok || body.error) throw new Error(body.error?.message ?? "Fund failed");
          fundSuccess.value = `成功充值 ${amount} PANGU2 到奖励池`;
          await fetchCoverage(); // refresh
        } catch (e: unknown) {
          fundError.value = e instanceof Error ? e.message : "充值失败";
        } finally {
          fundLoading.value = false;
        }
      },
    };
  }

  // ── Admin: Set Reward Rate ────────────────
  function requestSetRewardRate(rate: string) {
    if (!rate || rate === "0") {
      rateError.value = "请输入有效速率";
      return;
    }
    const rateFormatted = parseFloat(rate) > 1 ? `${(parseFloat(rate) / 1e12).toFixed(2)} token/天` : `${rate} wei/s`;
    confirmModal.value = {
      type: "rate",
      title: "确认设置奖励速率",
      summary: `速率: ${rate} (约 ${rateFormatted})\n操作: set-reward-rate\n此操作需要 SUPER_ADMIN 权限`,
      action: async () => {
        rateLoading.value = true;
        rateError.value = null;
        rateSuccess.value = null;
        try {
          const res = await adminFetch("/staking/set-reward-rate", {
            method: "POST",
            body: JSON.stringify({ rewardRate: rate } satisfies SetRewardRateRequest),
          });
          const body = await res.json();
          if (!res.ok || body.error) throw new Error(body.error?.message ?? "Set rate failed");
          rateSuccess.value = `成功设置奖励速率为 ${rate}`;
          await fetchCoverage(); // refresh
        } catch (e: unknown) {
          rateError.value = e instanceof Error ? e.message : "设置速率失败";
        } finally {
          rateLoading.value = false;
        }
      },
    };
  }

  function confirmAction() {
    confirmModal.value?.action();
    confirmModal.value = null;
  }

  function cancelAction() {
    confirmModal.value = null;
  }

  // ── Refresh all ────────────────────────────
  async function refreshAll() {
    await Promise.all([fetchCoverage(), fetchStatus()]);
  }

  onMounted(refreshAll);

  return {
    // state
    loading, error, dataStatus,
    // coverage
    coverage, coverageLoading, fetchCoverage,
    // status
    status, statusLoading, fetchStatus,
    // positions
    positions, positionsLoading, searchAddress, searchPositions,
    // fund
    fundLoading, fundError, fundSuccess, requestFundRewards,
    // rate
    rateLoading, rateError, rateSuccess, requestSetRewardRate,
    // confirm
    confirmModal, confirmAction, cancelAction,
    // refresh
    refreshAll,
  };
}
