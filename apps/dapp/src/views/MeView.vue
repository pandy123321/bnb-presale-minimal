<!--
  PANGU2 DApp — MeView (我的)
  对接 /wallets/{address}/summary API
  显示: 余额、成本、税率、排名、排行榜位置
  硬规则:
  - 所有数据来自 API，不前端计算
  - 钱包未连接时显示连接入口
  - 税率只展示，不能修改
-->
<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";
import { useWalletStore } from "@/stores/useWallet";
import { useProfile } from "@/features/profile/useProfile";
import { DataStatus } from "@pangu2/api-types";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ErrorState from "@/components/common/ErrorState.vue";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";

const router = useRouter();
const wallet = useWalletStore();

const userAddr = computed(() =>
  wallet.isConnected ? wallet.address : null,
);

const { summary, isLoading, isMockData, hasData, rankTier, formatTokenBalance } =
  useProfile(userAddr);

// ── 派生 ────────────────────────────────────

const summaryData = computed(() => summary.state.value.data);
const summaryMeta = computed(() => summary.state.value.meta);

const displayBalance = computed(() => {
  if (!summaryData.value) return "—";
  // 优先使用 API 返回的 formatted 值
  return summaryData.value.balance_token_formatted || formatTokenBalance(summaryData.value.balance_token_raw);
});

const displayRank = computed(() => summaryData.value?.rank ?? null);
const displayTaxRate = computed(() => summaryData.value?.current_sell_tax_rate ?? "—");
const displayCostBasis = computed(() => summaryData.value?.cost_basis ?? "—");
const displayClaimable = computed(() => {
  if (!summaryData.value?.claimable_amount_raw) return "—";
  const raw = summaryData.value.claimable_amount_raw;
  const num = parseFloat(raw) / 1e18;
  if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M P2`;
  return `${Math.round(num).toLocaleString()} P2`;
});

// 排名状态
const rankLabel = computed(() => {
  if (!displayRank.value) return "未进入排名";
  if (displayRank.value <= 100) return `前100名 · #${displayRank.value}`;
  return `#${displayRank.value}`;
});
const isRanked = computed(() => displayRank.value !== null && displayRank.value <= 100);

// 是否已领取
const isClaimed = computed(() => {
  if (!summaryData.value?.claimable_amount_raw) return false;
  return summaryData.value.claimable_amount_raw === "0";
});
</script>

<template>
  <div>
    <div class="page-title">
      <h1>我的</h1>
      <p>{{ wallet.isConnected ? '合约记录成本、当前税率和链上记录。' : '连接钱包查看个人资产、排名和分红。' }}</p>
    </div>

    <DataStatusBanner
      v-if="summaryMeta"
      :data-status="summaryMeta.data_status"
      :block-number="summaryMeta.block_number"
    />

    <!-- 未连接状态 -->
    <div v-if="!wallet.isConnected" class="card" style="text-align:center; padding:24px">
      <div class="profile-avatar" style="margin:0 auto 12px">?</div>
      <p style="color:var(--muted); font-size:12px; margin-bottom:12px">连接钱包查看链上资产、排名和分红。</p>
      <button class="full-btn" @click="wallet.openConnectSheet()">连接钱包</button>
    </div>

    <!-- 已连接：加载中 -->
    <LoadingSpinner v-if="wallet.isConnected && isLoading && !summaryData" label="加载资产数据..." />

    <!-- 错误 -->
    <ErrorState
      v-if="summary.state.value.error && !isLoading"
      :message="summary.state.value.error ?? '获取失败'"
      :retryable="summary.state.value.errorRetryable"
      compact
      @retry="summary.execute()"
    />

    <!-- 资产卡片 -->
    <template v-if="wallet.isConnected && summaryData">
      <div class="card">
        <!-- 头像 + 地址 -->
        <div class="profile">
          <div class="profile-avatar">ME</div>
          <div>
            <b>{{ wallet.shortAddress }}</b>
            <p>{{ wallet.chainName }}{{ wallet.chainId ? ` · Chain ${wallet.chainId}` : '' }}</p>
          </div>
        </div>

        <!-- 余额 -->
        <div class="asset-main">{{ displayBalance }} PANGU2</div>
        <div class="asset-sub" v-if="displayCostBasis !== '—'">合约记录成本 {{ displayCostBasis }}</div>

        <!-- 状态标签 -->
        <div class="status-line">
          <span class="status-chip on">钱包已连接</span>
          <span class="status-chip" :class="{ on: isRanked }">
            {{ rankLabel }}
          </span>
          <span v-if="rankTier" class="status-chip on">{{ rankTier.name }} · {{ rankTier.share }}%</span>
          <span class="status-chip" :class="{ claimed: isClaimed, unclaimed: !isClaimed }">
            {{ isClaimed ? '分红已领取' : '分红未领取' }}
          </span>
        </div>

      <!-- 成本 / 税率 -->
      <div class="card" style="margin-top:11px">
        <div class="row">
          <span>合约记录成本</span>
          <b>{{ displayCostBasis }}</b>
        </div>
        <div class="row">
          <span>当前卖出协议税率</span>
          <b class="tax-value">{{ displayTaxRate }}</b>
        </div>
        <div class="row">
          <span>可领取分红</span>
          <b class="gold">{{ displayClaimable }}</b>
        </div>
        <div class="row">
          <span>排名档位</span>
          <b>{{ rankTier ? `${rankTier.name} (${rankTier.share}%)` : '—' }}</b>
        </div>
      </div>
    </template>

    <!-- 菜单 -->
    <div class="card menu" style="margin-top:11px">
      <button @click="router.push('/dividend')">
        <span class="menu-icon">◇</span><span>我的分红</span><span>›</span>
      </button>
      <button @click="router.push('/support')">
        <span class="menu-icon">⌁</span><span>托底池与锁仓</span><span>›</span>
      </button>
      <button disabled>
        <span class="menu-icon">⌘</span><span>合约透明度</span><span>›</span>
      </button>
      <button disabled>
        <span class="menu-icon">i</span><span>协议税费规则</span><span>›</span>
      </button>
      <button v-if="wallet.isConnected" @click="wallet.disconnect()">
        <span class="menu-icon">↪</span><span>断开钱包</span><span>›</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }

.profile { display: flex; align-items: center; gap: 10px; }
.profile-avatar { width: 42px; height: 42px; border-radius: 14px; background: rgba(216,170,81,.1); color: var(--gold2); display: grid; place-items: center; font-weight: 950; font-size: 16px; }
.profile b { font-size: 12px; }
.profile p { margin-top: 4px; color: var(--muted); font-size: 9px; }

.asset-main { font-size: 27px; font-weight: 950; margin-top: 17px; }
.asset-sub { font-size: 10px; color: var(--muted); margin-top: 4px; }

.status-line { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 12px; }
.status-chip { padding: 5px 7px; border-radius: 99px; font-size: 8px; color: var(--muted); border: 1px solid var(--line); }
.status-chip.on { color: var(--green); border-color: rgba(67,207,139,.22); background: rgba(67,207,139,.04); }
.status-chip.claimed { color: var(--green); border-color: rgba(67,207,139,.22); background: rgba(67,207,139,.04); }
.status-chip.unclaimed { color: var(--orange); border-color: rgba(243,163,75,.18); background: rgba(243,163,75,.04); }

.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 9px 0; font-size: 11px; }
.row+.row { border-top: 1px solid rgba(255,255,255,.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.tax-value { font-size: 18px !important; color: var(--gold2); }
.gold { color: var(--gold2); font-weight: 700; }

.menu button { width: 100%; display: grid; grid-template-columns: 30px 1fr auto; align-items: center; text-align: left; border: 0; background: none; padding: 12px 0; color: inherit; cursor: pointer; }
.menu button:disabled { opacity: 0.4; cursor: not-allowed; }
.menu button+button { border-top: 1px solid rgba(255,255,255,.05); }
.menu-icon { width: 26px; height: 26px; border-radius: 9px; background: #20242c; display: grid; place-items: center; color: var(--gold2); font-size: 11px; }
.menu button>span:nth-child(2) { font-size: 11px; }
.menu button>span:last-child { color: var(--muted); }

.mock-tag { font-size: 8px; font-weight: 900; letter-spacing: 0.05em; padding: 3px 7px; border-radius: 6px; color: var(--orange); background: rgba(243,163,75,.1); border: 1px solid rgba(243,163,75,.18); }
</style>
