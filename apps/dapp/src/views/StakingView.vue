<!--
  PANGU2 DApp — StakingView
  锁仓操作 + 我的仓位 + 收益领取
  硬规则:
  - MIN_STAKE = 1 token / MAX_LOCK = 730 days
  - 提前解锁弹窗显示 10% 罚金 + 没收收益
  - 链上操作由钱包签名，金额全部字符串
-->
<script setup lang="ts">
import { computed, ref } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import {
  useStaking,
  LOCK_PRESETS,
  MAX_LOCK_SECONDS,
  SECONDS_PER_DAY,
  validateStakeAmount,
  validateLockSeconds,
  formatTokenRaw,
  computePenalty,
} from "@/features/staking/useStaking";
import type { StakePositionSnapshot } from "@/stores/useStaking";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ErrorState from "@/components/common/ErrorState.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const wallet = useWalletStore();
const userAddr = computed(() => (wallet.isConnected ? wallet.address : null));

const {
  store,
  txPhase,
  txError,
  isBusy,
  apyPercent,
  claimableDisplay,
  totalStakedDisplay,
  totalEarnedDisplay,
  refresh,
  stake,
  unstake,
  earlyUnstake,
  claimRewards,
  resetTx,
  estimateUnlockAt,
  estimateNewStakeReward,
} = useStaking(userAddr);

// ── Form state ──────────────────────────────

const amountInput = ref("100");
const presetId = ref<string>("90");
const customDays = ref("90");

const lockSeconds = computed(() => {
  if (presetId.value === "custom") {
    const days = Number.parseInt(customDays.value, 10);
    if (!Number.isFinite(days) || days <= 0) return 0;
    return days * SECONDS_PER_DAY;
  }
  const preset = LOCK_PRESETS.find((p) => p.id === presetId.value);
  return preset?.seconds ?? 0;
});

const unlockEstimate = computed(() => {
  if (lockSeconds.value <= 0) return "—";
  return estimateUnlockAt(lockSeconds.value).toLocaleString("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
});

const estimatedRewardDisplay = computed(() =>
  formatTokenRaw(estimateNewStakeReward(amountInput.value, lockSeconds.value)),
);

const amountError = computed(() => {
  if (!amountInput.value.trim()) return null;
  return validateStakeAmount(amountInput.value);
});

const lockError = computed(() => validateLockSeconds(lockSeconds.value));

const canStake = computed(
  () =>
    wallet.canTransact &&
    !isBusy.value &&
    !amountError.value &&
    !lockError.value &&
    amountInput.value.trim() !== "",
);

const phaseLabel = computed(() => {
  switch (txPhase.value) {
    case "approving":
      return "授权中，请在钱包确认...";
    case "staking":
      return "锁仓中，请在钱包确认...";
    case "unstaking":
      return "解锁中，请在钱包确认...";
    case "early_unstaking":
      return "提前解锁中，请在钱包确认...";
    case "claiming":
      return "领取中，请在钱包确认...";
    case "confirming":
      return "等待链上确认...";
    case "success":
      return "操作成功";
    case "rejected":
      return "已取消";
    case "failed":
      return txError.value ?? "操作失败";
    default:
      return "";
  }
});

// ── Early unstake dialog ────────────────────

const earlyDialog = ref<{
  open: boolean;
  position: StakePositionSnapshot | null;
}>({ open: false, position: null });

const earlyPenaltyDisplay = computed(() => {
  const pos = earlyDialog.value.position;
  if (!pos) return "0 P2";
  return formatTokenRaw(computePenalty(pos.amount));
});

const earlyForfeitDisplay = computed(() => {
  const pos = earlyDialog.value.position;
  if (!pos) return "0 P2";
  return formatTokenRaw(pos.earnedEstimate);
});

const earlyNetDisplay = computed(() => {
  const pos = earlyDialog.value.position;
  if (!pos) return "0 P2";
  const net = (BigInt(pos.amount) - BigInt(computePenalty(pos.amount))).toString();
  return formatTokenRaw(net);
});

function openEarlyDialog(pos: StakePositionSnapshot): void {
  earlyDialog.value = { open: true, position: pos };
}

function closeEarlyDialog(): void {
  earlyDialog.value = { open: false, position: null };
}

async function confirmEarlyUnstake(): Promise<void> {
  const pos = earlyDialog.value.position;
  if (!pos) return;
  closeEarlyDialog();
  await earlyUnstake(pos.positionId);
}

// ── Actions ─────────────────────────────────

async function handleStake(): Promise<void> {
  if (!wallet.isConnected) {
    wallet.openConnectSheet();
    return;
  }
  resetTx();
  await stake(amountInput.value, lockSeconds.value);
}

async function handleUnstake(pos: StakePositionSnapshot): Promise<void> {
  if (!wallet.isConnected) {
    wallet.openConnectSheet();
    return;
  }
  resetTx();
  await unstake(pos.positionId);
}

async function handleClaim(): Promise<void> {
  if (!wallet.isConnected) {
    wallet.openConnectSheet();
    return;
  }
  resetTx();
  await claimRewards();
}

function statusLabel(status: StakePositionSnapshot["status"]): string {
  if (status === "locked") return "锁定中";
  if (status === "matured") return "已到期";
  return "已取出";
}

function statusClass(status: StakePositionSnapshot["status"]): string {
  if (status === "locked") return "locked";
  if (status === "matured") return "matured";
  return "claimed";
}

function formatUnlockDate(unlockAt: string): string {
  const ts = Number(unlockAt);
  if (!Number.isFinite(ts) || ts <= 0) return "—";
  return new Date(ts * 1000).toLocaleDateString("zh-CN");
}
</script>

<template>
  <div>
    <div class="page-title">
      <h1>锁仓</h1>
      <p>锁定 P2 赚取奖励。到期解锁本金，或提前解锁（扣 10% 罚金并没收收益）。</p>
    </div>

    <DataStatusBanner
      v-if="store.dataStatus"
      :data-status="store.dataStatus"
      :block-number="store.blockNumber"
    />

    <LoadingSpinner v-if="store.loading && !store.globalStatus" label="加载锁仓数据..." />

    <ErrorState
      v-if="store.error && !store.loading"
      :message="store.error"
      retryable
      compact
      @retry="refresh"
    />

    <!-- A) 锁仓操作 -->
    <div class="section-head"><h2>锁仓操作</h2></div>
    <div class="card">
      <label class="field-label">锁仓数量 (P2)</label>
      <input
        v-model="amountInput"
        class="field-input"
        type="text"
        inputmode="decimal"
        placeholder="最小 1"
        :disabled="isBusy"
      />
      <p v-if="amountError" class="field-error">{{ amountError }}</p>

      <label class="field-label" style="margin-top:12px">锁仓时长</label>
      <div class="preset-row">
        <button
          v-for="p in LOCK_PRESETS"
          :key="p.id"
          type="button"
          class="preset-btn"
          :class="{ active: presetId === p.id }"
          :disabled="isBusy"
          @click="presetId = p.id"
        >
          {{ p.label }}
        </button>
      </div>
      <div v-if="presetId === 'custom'" class="custom-row">
        <input
          v-model="customDays"
          class="field-input"
          type="text"
          inputmode="numeric"
          placeholder="天数 (≤730)"
          :disabled="isBusy"
        />
        <span class="custom-hint">天 · 上限 {{ Math.floor(MAX_LOCK_SECONDS / SECONDS_PER_DAY) }}</span>
      </div>
      <p v-if="lockError" class="field-error">{{ lockError }}</p>

      <div class="meta-rows">
        <div class="row"><span>当前年化收益率</span><b class="gold">{{ apyPercent }}%</b></div>
        <div class="row"><span>解锁时间预估</span><b>{{ unlockEstimate }}</b></div>
        <div class="row"><span>预估锁仓收益</span><b>{{ estimatedRewardDisplay }}</b></div>
      </div>

      <button
        class="full-btn"
        style="margin-top:14px"
        :disabled="!canStake && wallet.isConnected"
        @click="handleStake"
      >
        <template v-if="!wallet.isConnected">连接钱包</template>
        <template v-else-if="isBusy">{{ phaseLabel || '处理中...' }}</template>
        <template v-else>确认锁仓</template>
      </button>
      <p v-if="txPhase !== 'idle' && phaseLabel" class="tx-hint" :class="txPhase">
        {{ phaseLabel }}
      </p>
    </div>

    <!-- B) 我的仓位 -->
    <div class="section-head"><h2>我的仓位</h2></div>
    <div class="card">
      <div class="summary-grid">
        <div>
          <small>总锁仓量</small>
          <b>{{ wallet.isConnected ? totalStakedDisplay : '—' }}</b>
        </div>
        <div class="right">
          <small>总预估收益</small>
          <b>{{ wallet.isConnected ? totalEarnedDisplay : '—' }}</b>
        </div>
      </div>

      <template v-if="!wallet.isConnected">
        <EmptyState title="连接钱包后查看仓位" />
      </template>
      <template v-else-if="store.positions.length === 0 && !store.loading">
        <EmptyState title="暂无锁仓仓位" />
      </template>
      <template v-else>
        <div
          v-for="pos in store.positions"
          :key="pos.positionId"
          class="pos-row"
        >
          <div class="pos-main">
            <div class="pos-top">
              <b>#{{ pos.positionId }} · {{ formatTokenRaw(pos.amount) }}</b>
              <span class="status-tag" :class="statusClass(pos.status)">
                {{ statusLabel(pos.status) }}
              </span>
            </div>
            <div class="pos-meta">
              <span>剩余 {{ pos.remainingDays }} 天</span>
              <span>预估 {{ formatTokenRaw(pos.earnedEstimate) }}</span>
              <span>解锁 {{ formatUnlockDate(pos.unlockAt) }}</span>
            </div>
          </div>
          <div class="pos-actions">
            <button
              v-if="pos.status === 'matured'"
              class="action-btn"
              :disabled="isBusy"
              @click="handleUnstake(pos)"
            >
              解锁
            </button>
            <button
              v-else-if="pos.status === 'locked'"
              class="action-btn warn"
              :disabled="isBusy"
              @click="openEarlyDialog(pos)"
            >
              提前解锁
            </button>
            <span v-else class="done-label">已取出</span>
          </div>
        </div>
      </template>
    </div>

    <!-- C) 收益领取 -->
    <div class="section-head"><h2>收益</h2></div>
    <div class="card">
      <div class="claim-box">
        <div>
          <small>可领取收益</small>
          <b>{{ wallet.isConnected ? claimableDisplay : '—' }}</b>
          <p class="sub">领取收益不会解锁本金</p>
        </div>
        <button
          class="claim-btn"
          :disabled="isBusy || (wallet.isConnected && (!wallet.canTransact || store.earnedRaw === '0'))"
          @click="handleClaim"
        >
          <template v-if="!wallet.isConnected">连接钱包</template>
          <template v-else-if="isBusy && (txPhase === 'claiming' || txPhase === 'confirming')">领取中...</template>
          <template v-else>领取收益</template>
        </button>
      </div>
    </div>

    <!-- Early unstake confirm -->
    <div v-if="earlyDialog.open" class="modal-mask" @click.self="closeEarlyDialog">
      <div class="modal">
        <h3>确认提前解锁？</h3>
        <p class="sub">提前解锁将扣除 10% 罚金，并没收该仓位对应的未领取收益。</p>
        <div class="meta-rows" style="margin-top:12px">
          <div class="row"><span>仓位本金</span><b>{{ earlyDialog.position ? formatTokenRaw(earlyDialog.position.amount) : '—' }}</b></div>
          <div class="row"><span>10% 罚金</span><b class="danger">-{{ earlyPenaltyDisplay }}</b></div>
          <div class="row"><span>没收收益</span><b class="danger">-{{ earlyForfeitDisplay }}</b></div>
          <div class="row"><span>预计到账</span><b>{{ earlyNetDisplay }}</b></div>
        </div>
        <div class="modal-actions">
          <button class="secondary-btn" type="button" @click="closeEarlyDialog">取消</button>
          <button class="primary-btn danger-btn" type="button" @click="confirmEarlyUnstake">确认提前解锁</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }

.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }

.field-label {
  display: block;
  font-size: 10px;
  color: var(--muted);
  margin-bottom: 6px;
}

.field-input {
  width: 100%;
  height: 44px;
  border-radius: 12px;
  border: 1px solid var(--line);
  background: rgba(255,255,255,.03);
  color: var(--text);
  padding: 0 12px;
  font-size: 14px;
  font-weight: 700;
}

.field-error {
  margin-top: 6px;
  font-size: 10px;
  color: var(--red);
}

.preset-row {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 6px;
}

.preset-btn {
  height: 34px;
  border-radius: 10px;
  border: 1px solid var(--line);
  background: rgba(255,255,255,.03);
  font-size: 10px;
  font-weight: 700;
  color: var(--muted);
}

.preset-btn.active {
  color: var(--gold2);
  border-color: rgba(216,170,81,.45);
  background: rgba(216,170,81,.08);
}

.custom-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}

.custom-hint { font-size: 10px; color: var(--muted); white-space: nowrap; }

.meta-rows { margin-top: 12px; }
.row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 0;
  font-size: 11px;
}
.row + .row { border-top: 1px solid rgba(255,255,255,.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.gold { color: var(--gold2); }
.danger { color: var(--red); }

.tx-hint {
  margin-top: 10px;
  font-size: 10px;
  text-align: center;
  color: var(--muted);
}
.tx-hint.success { color: var(--green); }
.tx-hint.failed, .tx-hint.rejected { color: var(--red); }

.mock-tip {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-top: 12px;
}

.summary-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 12px;
}
.summary-grid small { display: block; font-size: 9px; color: var(--muted); }
.summary-grid b { display: block; margin-top: 4px; font-size: 15px; color: var(--gold2); }
.summary-grid .right { text-align: right; }

.pos-row {
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 12px 0;
  border-top: 1px solid rgba(255,255,255,.04);
}

.pos-main { flex: 1; min-width: 0; }
.pos-top {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  align-items: center;
}
.pos-top b { font-size: 12px; }
.pos-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 5px;
  font-size: 9px;
  color: var(--muted);
}

.status-tag {
  font-size: 9px;
  font-weight: 700;
  padding: 3px 7px;
  border-radius: 6px;
}
.status-tag.locked {
  color: var(--orange);
  background: rgba(243,163,75,.08);
  border: 1px solid rgba(243,163,75,.18);
}
.status-tag.matured {
  color: var(--green);
  background: rgba(67,207,139,.08);
  border: 1px solid rgba(67,207,139,.18);
}
.status-tag.claimed {
  color: var(--muted);
  background: rgba(255,255,255,.04);
  border: 1px solid var(--line);
}

.action-btn {
  height: 32px;
  padding: 0 10px;
  border-radius: 10px;
  border: 0;
  background: linear-gradient(135deg, var(--gold2), var(--gold));
  color: #171108;
  font-size: 10px;
  font-weight: 900;
  white-space: nowrap;
}
.action-btn.warn {
  background: rgba(243,163,75,.12);
  color: var(--orange);
  border: 1px solid rgba(243,163,75,.28);
}
.done-label { font-size: 10px; color: var(--muted); }

.claim-box {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.claim-box small { display: block; font-size: 9px; color: var(--muted); }
.claim-box b { display: block; margin-top: 4px; font-size: 18px; color: var(--gold2); }
.claim-btn {
  height: 40px;
  padding: 0 14px;
  border: 0;
  border-radius: 12px;
  background: linear-gradient(135deg, var(--gold2), var(--gold));
  color: #171108;
  font-weight: 900;
  font-size: 12px;
  white-space: nowrap;
}

.modal-mask {
  position: fixed;
  inset: 0;
  z-index: 80;
  background: rgba(0,0,0,.62);
  display: grid;
  place-items: end center;
  padding: 16px;
}
.modal {
  width: min(100%, 400px);
  border-radius: 18px 18px 14px 14px;
  border: 1px solid var(--line);
  background: var(--panel);
  padding: 18px 16px 16px;
  margin-bottom: calc(70px + env(safe-area-inset-bottom));
}
.modal h3 { font-size: 16px; margin-bottom: 6px; }
.modal-actions {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 8px;
  margin-top: 16px;
}
.danger-btn {
  background: linear-gradient(135deg, #ff9a9e, var(--red));
  color: #1a0808;
}
</style>
