<!--
  PANGU2 DApp — DividendView
  对接 /dividend/epochs/current 和 /dividend/epochs/{id}/proof/{addr} API
  显示: 当前Epoch、分红档位、用户Proof（排名/可领取/已领取）
  硬规则:
  - 估算排名、结算排名、可领取金额分开显示
  - Proof 来自 API，不由前端计算
  - Claim 由钱包签名
-->
<script setup lang="ts">
import { computed, watch } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import { useDividend } from "@/features/dividend/useDividend";
import { DataStatus } from "@pangu2/api-types";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ErrorState from "@/components/common/ErrorState.vue";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";

const wallet = useWalletStore();

// 用户地址（响应式）
const userAddr = computed(() =>
  wallet.isConnected ? wallet.address : null,
);

const { epoch, proof, isLoading, isMockData, epochStatus, claimOpen, isClaimable, fetchProof } =
  useDividend(userAddr);

// 连接后自动拉 Proof
watch(
  () => wallet.isConnected,
  (connected) => {
    if (connected) fetchProof();
  },
);

// ── 显示数据 ────────────────────────────────

const epochData = computed(() => epoch.state.value.data);
const epochMeta = computed(() => epoch.state.value.meta);
const proofData = computed(() => proof.state.value.data);
const hasProof = computed(() => !!proofData.value);
const myClaimable = computed(() => {
  if (!proofData.value || proofData.value.claimed) return "—";
  // amount_raw is a wei string
  const raw = proofData.value.amount_raw;
  if (!raw) return "0";
  // 简单格式化 (mock 数据量级不需要 18 位精度)
  const num = parseFloat(raw) / 1e18;
  if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M P2`;
  return `${Math.round(num).toLocaleString()} P2`;
});

// Mock 排名（最终来自 wallet summary，当前从 const 获取）
const mockRank = 36;
const mockDistanceToTier = 18160;
const goalPercent = Math.min(100, Math.round((mockRank / 30) * 72));

// ── Claim 按钮行为（Mock 阶段） ───────────
const claiming = computed(() => false);

function handleClaim(): void {
  // Mock: 模拟钱包签名交互（F07 实现真正链上 claim）
  if (!wallet.isConnected) {
    wallet.openConnectSheet();
    return;
  }
  alert("Mock: Claim 由钱包签名（F07 实现真正链上调用）");
}
</script>

<template>
  <div>
    <div class="page-title">
      <h1>前100名分红</h1>
      <p>买入税4%进入分红池，排名按公开快照计算。Claims 由钱包签名。</p>
    </div>

    <!-- 数据状态横幅 -->
    <DataStatusBanner
      v-if="epochMeta"
      :data-status="epochMeta.data_status"
      :block-number="epochMeta.block_number"
    />

    <!-- 加载中 -->
    <LoadingSpinner v-if="isLoading && !epochData" label="加载分红数据..." />

    <!-- 错误 -->
    <ErrorState
      v-if="epoch.state.value.error && !isLoading && !epochData"
      :message="epoch.state.value.error ?? '获取失败'"
      :retryable="epoch.state.value.errorRetryable"
      compact
      @retry="epoch.execute()"
    />

    <!-- 当前 Epoch 数据卡片 -->
    <template v-if="epochData">
      <div class="card rank-card">
        <!-- 对比区域: 估算排名 vs 结算排名 vs 可领取 -->
        <div class="rank-top">
          <div class="rank-number">
            <small>估算排名</small>
            <b>{{ wallet.isConnected ? `#${mockRank}` : '—' }}</b>
          </div>
          <div class="rank-number">
            <small>结算排名</small>
            <b>{{ hasProof ? `#${mockRank}` : '—' }}</b>
          </div>
          <div class="claim-box">
            <small>本周期可领取</small>
            <b>{{ wallet.isConnected ? myClaimable : '—' }}</b>
            <small v-if="proofData?.claimed" style="color:var(--green)">已领取 ✓</small>
          </div>
        </div>

        <!-- 距离下一档 -->
        <div class="rank-goal">
          <div class="rank-goal-top">
            <b>{{ wallet.isConnected ? `距离前30名还差 ${mockDistanceToTier.toLocaleString()} P2` : '连接钱包查看排名' }}</b>
            <span>{{ wallet.isConnected ? `${goalPercent}%` : '—' }}</span>
          </div>
          <div class="progress">
            <i :style="{ width: wallet.isConnected ? `${goalPercent}%` : '5%' }"></i>
          </div>
          <div class="rank-labels"><span>#100</span><span>#60</span><span>#30</span><span>#10</span></div>
        </div>

        <!-- Claim 按钮 / 连接钱包 -->
        <button
          class="full-btn"
          style="margin-top:14px"
          :disabled="!wallet.isConnected || !isClaimable || claiming"
          @click="handleClaim"
        >
          <template v-if="!wallet.isConnected">连接钱包</template>
          <template v-else-if="claiming">签名中...</template>
          <template v-else-if="!epochData">加载中...</template>
          <template v-else-if="proofData?.claimed">已领取</template>
          <template v-else-if="!claimOpen">Epoch 未开放领取</template>
          <template v-else-if="!hasProof">无可领取分红</template>
          <template v-else>领取 {{ myClaimable }}</template>
        </button>

        <!-- Claim 状态标记 -->
      </div>
    </template>

    <!-- 分红档位（静态，来自 domain 常量） -->
    <div class="section-head"><h2>分红档位</h2></div>
    <div class="tiers">
      <div class="tier" v-for="tier in (epochData?.tiers ?? [])" :key="tier.name"
        :class="{ active: tier.rank_range.includes(String(mockRank).slice(0,2)) }">
        <b>{{ tier.share_percent }}%</b>
        <span>第{{ tier.rank_range }}名</span>
      </div>
    </div>

    <!-- Epoch 信息 -->
    <div v-if="epochData" class="section-head">
      <h2>Epoch #{{ epochData.epoch_id }} 信息</h2>
    </div>
    <div v-if="epochData" class="card">
      <div class="row"><span>快照区块</span><b>#{{ epochData.snapshot_block }}</b></div>
      <div class="row"><span>分红总额</span><b>{{ (parseFloat(epochData.total_dividend_raw) / 1e18).toLocaleString() }} P2</b></div>
      <div class="row"><span>Merkle Root</span><b class="mono">{{ epochData.merkle_root.slice(0, 12) }}...</b></div>
      <div class="row">
        <span>状态</span>
        <b class="tag" :class="claimOpen ? 'ok' : 'warning'">
          {{ epochStatus === 'claim_open' ? '领取开放' : epochStatus }}
        </b>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }

.rank-card { text-align: center; padding: 18px; }
.rank-top {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 8px;
  text-align: left;
}
.rank-number small, .claim-box small { display: block; color: var(--muted); font-size: 9px; }
.rank-number b { display: block; color: var(--gold2); font-size: 24px; margin-top: 3px; }
.claim-box { text-align: right; }
.claim-box b { display: block; font-size: 15px; margin-top: 5px; }

.rank-goal { margin-top: 14px; text-align: left; }
.rank-goal-top { display: flex; justify-content: space-between; color: var(--muted); font-size: 9px; }
.rank-goal-top b { font-size: 10px; color: var(--text); }
.rank-labels { display: flex; justify-content: space-between; color: #676d79; font-size: 8px; margin-top: 5px; }
.progress { height: 6px; background: #252932; border-radius: 99px; overflow: hidden; margin-top: 10px; }
.progress i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), var(--gold2)); border-radius: inherit; transition: .3s; }

.tiers { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; }
.tier { padding: 10px 4px; border-radius: 12px; border: 1px solid var(--line); text-align: center; }
.tier.active { border-color: rgba(216,170,81,.4); background: rgba(216,170,81,.06); }
.tier b { display: block; font-size: 13px; color: var(--gold2); }
.tier span { font-size: 8px; color: var(--muted); }

.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }

.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 9px 0; font-size: 11px; }
.row+.row { border-top: 1px solid rgba(255,255,255,.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.mono { font-family: monospace; font-size: 10px !important; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }

.mock-tip { display: flex; gap: 8px; align-items: center; margin-top: 12px; justify-content: center; }
.mock-tip small { color: var(--muted); font-size: 9px; }
</style>
