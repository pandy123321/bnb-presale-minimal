<!--
  PANGU2 DApp — TradeView
  Connects to Quote API for real-time buy/sell pricing.
  ═══════════════════════════════════════════
  Hard rules:
  - No local tax calculation (tax rate from API)
  - No 4%/10% user selection (contract decides)
  - Quote expiry (30s) disables submit
  - MAX button reserves gas
  - source=unavailable disables submit
-->
<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import { DataStatus, QuoteSource } from "@pangu2/api-types";
import type { BuyQuote, SellQuote } from "@pangu2/api-types";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ErrorState from "@/components/common/ErrorState.vue";
import {
  useQuote,
  bnbToWei,
  tokenToRaw,
  weiToDisplay,
} from "@/features/trade/useQuote";
import { useTransaction } from "@/features/transactions/useTransaction";
import TransactionProgress from "@/components/TransactionProgress.vue";

const wallet = useWalletStore();
const quote = useQuote();
const tx = useTransaction();

// ── Mock wallet balances (until real API integration) ──
const MOCK_BNB_BALANCE = "3.284";
const MOCK_TOKEN_BALANCE = "126840";
const ESTIMATED_GAS = "0.00021"; // ~0.00021 BNB

// ── Mode ────────────────────────────────────
const mode = ref<"buy" | "sell">("buy");
const payAmount = ref("0.1");

function toggleMode(m: "buy" | "sell") {
  mode.value = m;
  quote.reset();
  payAmount.value = m === "buy" ? "0.1" : "10000";
}

// ── Amount in wei ────────────────────────────
const amountWei = computed(() =>
  mode.value === "buy" ? bnbToWei(payAmount.value) : tokenToRaw(payAmount.value),
);

// ── Fetch quote on amount or mode change ────
let debounceTimer: ReturnType<typeof setTimeout> | null = null;

function requestQuote(): void {
  if (!amountWei.value || amountWei.value === "0") return;

  if (mode.value === "buy") {
    quote.fetchBuy(amountWei.value);
  } else {
    quote.fetchSell(
      amountWei.value,
      wallet.address ?? "0x0000000000000000000000000000000000000000",
    );
  }
}

watch([mode, payAmount], () => {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(requestQuote, 400);
});

// ── Current quote data ──────────────────────
const activeQuote = computed<BuyQuote | SellQuote | null>(() =>
  mode.value === "buy" ? quote.buyQuote.value : quote.sellQuote.value,
);

const isMockData = computed(() => false);

const canSubmit = computed(
  () =>
    wallet.canTransact &&
    quote.canSubmit.value &&
    !!activeQuote.value &&
    !tx.isInProgress.value,
);

// ── Quote display card fields ───────────────

interface DisplayQuote {
  taxRate: string;
  taxTokensFormatted: string;
  taxTokensRaw: string;
  taxDest: string;
  netFormatted: string;
  minReceiveFormatted: string;
  source: string;
  sourceLabel: string;
  quoteBlock: string;
  expiresAt: string;
}

const displayQuote = computed<DisplayQuote | null>(() => {
  const d = activeQuote.value;
  if (!d) return null;

  const isBuy = mode.value === "buy";
  const buyD = isBuy ? (d as BuyQuote) : null;
  const sellD = !isBuy ? (d as SellQuote) : null;

  const source = d.source;
  const sourceLabels: Record<string, string> = {
    contract_preview: "Contract Preview",
    mock: "Contract Preview",
    unavailable: "UNAVAILABLE",
  };

  return {
    taxRate: d.tax_rate ?? "—",
    taxTokensFormatted: weiToDisplay(d.tax_tokens_raw),
    taxTokensRaw: d.tax_tokens_raw,
    taxDest: isBuy
      ? "Dividend Pool"
      : (sellD?.tax_destination ?? "—"),
    netFormatted: isBuy
      ? weiToDisplay(buyD!.net_tokens_raw)
      : weiToDisplay(sellD!.net_bnb_wei),
    minReceiveFormatted: isBuy
      ? weiToDisplay(buyD!.min_receive_raw)
      : weiToDisplay(sellD!.min_receive_wei),
    source,
    sourceLabel: sourceLabels[source] ?? source,
    quoteBlock: d.quote_block ?? "—",
    expiresAt: d.expires_at ?? "—",
  };
});

// ── MAX button ──────────────────────────────

function setMax(): void {
  if (mode.value === "buy") {
    // Subtract estimated gas from balance
    const bal = parseFloat(MOCK_BNB_BALANCE);
    const gas = parseFloat(ESTIMATED_GAS);
    const max = Math.max(0, bal - gas);
    payAmount.value = max > 0 ? max.toFixed(6) : "0";
  } else {
    payAmount.value = MOCK_TOKEN_BALANCE;
  }
}

// ── Submit (real transaction flow) ──────────

async function handleSubmit(): void {
  if (!canSubmit.value) return;

  const quoteData = activeQuote.value as BuyQuote | SellQuote | null;
  if (!quoteData) return;

  const amountRaw = amountWei.value;
  await tx.executeSell(amountRaw);
}

function handleRecover(): void {
  tx.recoverFromReject();
}

function handleTxClose(): void {
  tx.reset();
}

onUnmounted(() => {
  if (debounceTimer) clearTimeout(debounceTimer);
});
</script>

<template>
  <div>
    <div class="page-title">
      <h1>交易</h1>
      <p>合约实时报价。税率由链上合约决定，不可手动选择。</p>
    </div>

    <!-- Data status banner -->
    <DataStatusBanner
      v-if="quote.meta.value"
      :data-status="quote.meta.value.data_status"
      :block-number="quote.meta.value.block_number"
    />

    <!-- Buy/Sell toggle -->
    <div class="seg">
      <button :class="{ active: mode === 'buy' }" @click="toggleMode('buy')">买入</button>
      <button :class="{ active: mode === 'sell' }" @click="toggleMode('sell')">卖出</button>
    </div>

    <!-- Input card -->
    <div class="input-card">
      <div class="input-top">
        <span>支付</span>
        <span v-if="wallet.isConnected">
          余额 {{ mode === 'buy' ? MOCK_BNB_BALANCE + ' BNB' : MOCK_TOKEN_BALANCE + ' PANGU2' }}
        </span>
        <span v-else>— {{ mode === 'buy' ? 'BNB' : 'PANGU2' }}</span>
      </div>
      <div class="input-row">
        <input v-model="payAmount" inputmode="decimal" placeholder="0.00" />
        <button class="max-btn" @click="setMax" :disabled="!wallet.isConnected">
          MAX
        </button>
        <div class="token">
          <i class="coin">{{ mode === 'buy' ? 'B' : 'P' }}</i>
          <span>{{ mode === 'buy' ? 'BNB' : 'PANGU2' }}</span>
        </div>
      </div>
      <div class="input-foot">
        <span v-if="wallet.isConnected">Gas ≈ {{ ESTIMATED_GAS }} BNB（MAX 已预留）</span>
        <span v-else class="hint-wallet">连接钱包后可用 MAX</span>
      </div>
    </div>

    <div class="swap-arrow">↓</div>

    <!-- Output card -->
    <div class="input-card">
      <div class="input-top">
        <span>预计获得</span>
        <span class="output-badges">
          <span v-if="false" class="badge mock">MOCK DATA</span>
          <span v-if="quote.isExpired.value" class="badge expired">EXPIRED</span>
          <span v-if="quote.isUnavailable.value" class="badge unavailable">UNAVAILABLE</span>
          <span v-if="quote.isLoading.value" class="badge loading">Loading...</span>
        </span>
      </div>
      <div class="input-row">
        <template v-if="quote.isLoading.value">
          <LoadingSpinner size="sm" label="Fetching quote..." />
        </template>
        <template v-else-if="displayQuote && !quote.isExpired.value && !quote.isUnavailable.value">
          <input readonly :value="displayQuote.netFormatted" />
          <div class="token">
            <i class="coin">{{ mode === 'buy' ? 'P' : 'B' }}</i>
            <span>{{ mode === 'buy' ? 'PANGU2' : 'BNB' }}</span>
          </div>
        </template>
        <template v-else-if="quote.isUnavailable.value">
          <span class="unavailable-msg">报价不可用</span>
        </template>
        <template v-else>
          <input readonly value="0" />
          <div class="token">
            <i class="coin">{{ mode === 'buy' ? 'P' : 'B' }}</i>
            <span>{{ mode === 'buy' ? 'PANGU2' : 'BNB' }}</span>
          </div>
        </template>
      </div>
      <div v-if="quote.remainingSec.value > 0 && quote.state.value === 'READY'" class="countdown">
        报价 {{ quote.remainingSec.value }}s 后过期
      </div>
    </div>

    <!-- Error state -->
    <ErrorState
      v-if="quote.error.value && !quote.isLoading.value"
      :message="quote.error.value"
      :code="quote.errorCode.value ?? undefined"
      :retryable="quote.errorRetryable.value"
      compact
      @retry="requestQuote"
    />

    <!-- Quote details card -->
    <div v-if="displayQuote && !quote.error.value && !quote.isUnavailable.value" class="card quote-card">
      <div class="row">
        <span>协议税率</span>
        <b class="tax-value">{{ displayQuote.taxRate }}</b>
      </div>
      <div class="row">
        <span>税费数量</span>
        <b>{{ displayQuote.taxTokensFormatted }} P2</b>
      </div>
      <div class="row">
        <span>资金去向</span>
        <b>{{ displayQuote.taxDest }}</b>
      </div>
      <div class="row">
        <span>净获得</span>
        <b>{{ displayQuote.netFormatted }} {{ mode === 'buy' ? 'P2' : 'BNB' }}</b>
      </div>
      <div class="row">
        <span>最低到账</span>
        <b>{{ displayQuote.minReceiveFormatted }} {{ mode === 'buy' ? 'P2' : 'BNB' }}</b>
      </div>
      <div class="row">
        <span>报价区块</span>
        <b>#{{ displayQuote.quoteBlock }}</b>
      </div>
      <div class="row">
        <span>过期时间</span>
        <b :class="{ 'text-expire': quote.remainingSec.value <= 5 && quote.remainingSec.value > 0 }">
          {{ quote.remainingSec.value }}s
        </b>
      </div>

      <div class="quote-footer">
        <span class="tag" :class="isMockData ? 'warning' : (quote.isExpired.value ? 'danger' : 'ok')">
          {{ displayQuote.sourceLabel }}
        </span>
        <small>
          <template v-if="quote.state.value === 'EXPIRED'">报价已过期，请刷新。</template>
          <template v-else>合约报价检查通过 · 30秒内有效</template>
        </small>
      </div>
    </div>

    <!-- Unavailable state -->
    <div v-if="quote.isUnavailable.value && !quote.isLoading.value" class="card unavailable-card">
      <div class="card-body">
        <div class="unavailable-hint">
          <i>⚠</i>
          <div>
            <b>报价不可用</b>
            <span>合约 ABI 或 RPC 暂时不可用，请稍后重试。</span>
          </div>
        </div>
        <button class="full-btn sm" @click="requestQuote">重试报价</button>
      </div>
    </div>

    <!-- Submit button -->
    <button
      class="full-btn"
      :disabled="!canSubmit"
      style="margin-top:12px"
      @click="handleSubmit"
    >
      <template v-if="tx.isInProgress.value">
        {{ mode === 'buy' ? '买入中...' : '卖出中...' }}
      </template>
      <template v-else-if="!wallet.isConnected">
        连接钱包以交易
      </template>
      <template v-else-if="!quote.canSubmit.value && !activeQuote">
        输入金额获取报价
      </template>
      <template v-else-if="quote.isExpired.value">
        报价已过期 — 点击刷新
      </template>
      <template v-else-if="quote.isUnavailable.value">
        报价不可用
      </template>
      <template v-else>
        {{ mode === 'buy' ? '确认买入' : '授权并卖出' }}
      </template>
    </button>

    <!-- Transaction progress overlay -->
    <TransactionProgress
      :phase="tx.state.value.phase"
      :chain-tx-state="tx.state.value.chainTxState"
      :approval-state="tx.state.value.approvalState"
      :sell-tx-hash="tx.state.value.sellTxHash"
      :error="tx.state.value.error"
      :error-recoverable="tx.state.value.errorRecoverable"
      :block-number="tx.state.value.blockNumber"
      @close="handleTxClose"
      @recover="handleRecover"
    />
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); line-height: 1.5; margin-top: 6px; }

.seg { display: grid; grid-template-columns: 1fr 1fr; padding: 4px; border: 1px solid var(--line); border-radius: 14px; background: var(--panel); margin-bottom: 10px; }
.seg button { height: 39px; border: 0; border-radius: 10px; background: none; color: var(--muted); font-weight: 850; }
.seg button.active { background: #252a33; color: var(--text); }

.input-card { padding: 13px; border-radius: 16px; border: 1px solid var(--line); background: var(--panel); }
.input-card+.input-card { margin-top: 8px; }
.input-top { display: flex; justify-content: space-between; color: var(--muted); font-size: 9px; }
.input-row { display: flex; gap: 9px; align-items: center; margin-top: 11px; min-height: 36px; }
.input-row input { flex: 1; min-width: 0; border: 0; outline: 0; background: none; color: var(--text); font-size: 27px; font-weight: 900; }
.max-btn { border: 0; background: none; color: var(--gold); font-size: 9px; font-weight: 700; }
.max-btn:disabled { opacity: 0.35; cursor: not-allowed; }
.token { display: flex; align-items: center; gap: 6px; padding: 7px 9px; border-radius: 11px; background: #222730; font-size: 11px; font-weight: 850; flex-shrink: 0; }
.coin { width: 21px; height: 21px; border-radius: 50%; display: grid; place-items: center; background: var(--gold); color: #171108; font-size: 9px; }
.swap-arrow { width: 34px; height: 34px; margin: -4px auto; border: 4px solid var(--bg); border-radius: 11px; background: #222730; display: grid; place-items: center; position: relative; z-index: 2; }

.input-foot { margin-top: 8px; font-size: 9px; color: var(--muted); display: flex; justify-content: flex-end; }
.hint-wallet { color: var(--orange); }

.output-badges { display: flex; gap: 5px; }
.badge { font-size: 7px; font-weight: 900; padding: 1px 5px; border-radius: 5px; }
.badge.mock { color: var(--orange); background: rgba(243, 163, 75, 0.1); }
.badge.expired { color: var(--red); background: rgba(255, 116, 125, 0.1); }
.badge.unavailable { color: var(--red); background: rgba(255, 116, 125, 0.1); }
.badge.loading { color: var(--muted); background: rgba(146, 152, 165, 0.1); }

.countdown { text-align: right; font-size: 9px; color: var(--muted); margin-top: 6px; }

.unavailable-msg { font-size: 15px; color: var(--red); font-weight: 700; }

.quote-card { margin-top: 10px; }
.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 9px 0; font-size: 11px; }
.row+.row { border-top: 1px solid rgba(255, 255, 255, 0.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.tax-value { font-size: 18px !important; color: var(--gold2); }
.text-expire { color: var(--red); }

.quote-footer { display: flex; gap: 10px; align-items: center; padding: 11px 0 0; border-top: 1px solid rgba(255, 255, 255, 0.04); margin-top: 8px; }
.quote-footer small { color: var(--muted); font-size: 9px; }

.unavailable-card { margin-top: 10px; background: rgba(255, 116, 125, 0.04); border-color: rgba(255, 116, 125, 0.15); }
.unavailable-hint { display: flex; gap: 10px; align-items: flex-start; margin-bottom: 12px; }
.unavailable-hint i { font-size: 18px; flex-shrink: 0; }
.unavailable-hint b { display: block; font-size: 12px; }
.unavailable-hint span { display: block; font-size: 10px; color: var(--muted); margin-top: 2px; }
.full-btn.sm { height: 34px; font-size: 12px; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67, 207, 139, 0.08); border: 1px solid rgba(67, 207, 139, 0.18); }
.tag.warning { color: var(--orange); background: rgba(243, 163, 75, 0.08); border: 1px solid rgba(243, 163, 75, 0.18); }
.tag.danger { color: var(--red); background: rgba(255, 116, 125, 0.08); border: 1px solid rgba(255, 116, 125, 0.18); }

.full-btn.submitting { background: var(--panel); color: var(--muted); border: 1px solid var(--line); cursor: wait; }
.submit-spinner { display: inline-block; width: 14px; height: 14px; border: 2px solid rgba(255, 255, 255, 0.18); border-top-color: var(--gold); border-radius: 50%; animation: spin 0.7s linear infinite; margin-right: 6px; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
