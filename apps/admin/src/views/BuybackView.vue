<script setup lang="ts">
import { ref, onMounted } from "vue";
import type { BuybackEventDto, LockerBatchDto } from "@pangu2/api-types";

const PUBLIC_API = "/api/v1/projects/pangu2";

const loadingBuybacks = ref(true);
const loadingBatches = ref(true);
const buybackError = ref<string | null>(null);
const batchError = ref<string | null>(null);

const buybacks = ref<BuybackEventDto[]>([]);
const batches = ref<LockerBatchDto[]>([]);
const buybacksTotal = ref(0);
const batchesTotal = ref(0);

// ── Formatting helpers (precision-safe decimal strings, no Number/parseFloat) ──
const NATIVE_DECIMALS = 18;
const TOKEN_DECIMALS = 18;
const TOKEN_SYMBOL = "PANGU2";

type FormattedAmount =
  | { valid: true; text: string }
  | { valid: false; text: "\u2014"; reason: string };

/** Validate a canonical on-chain amount: decimal unsigned integer string only */
function validateAmount(raw: unknown): string {
  if (raw === null || raw === undefined) {
    throw new Error("amount is null/undefined");
  }
  if (typeof raw !== "string" || !/^(0|[1-9]\d*)$/.test(raw)) {
    throw new Error(`Invalid on-chain amount: ${JSON.stringify(raw)}`);
  }
  return raw;
}

/** Format a native wei amount to BNB (18 decimals, max 6 fractional digits) */
function formatBnb(raw: unknown): FormattedAmount {
  try {
    const s = validateAmount(raw);
    if (s === "0") return { valid: true, text: "0 BNB" };
    const len = s.length;
    if (len <= NATIVE_DECIMALS) {
      const frac = s.padStart(NATIVE_DECIMALS, "0");
      const trimmed = frac.slice(0, 6).replace(/0+$/, "");
      return { valid: true, text: trimmed.length > 0 ? `0.${trimmed} BNB` : "<0.000001 BNB" };
    }
    const intPart = s.slice(0, len - NATIVE_DECIMALS);
    const fracPart = s.slice(len - NATIVE_DECIMALS, len - NATIVE_DECIMALS + 6).replace(/0+$/, "");
    return { valid: true, text: fracPart.length > 0 ? `${intPart}.${fracPart} BNB` : `${intPart} BNB` };
  } catch (e: unknown) {
    return { valid: false, text: "\u2014", reason: e instanceof Error ? e.message : "format error" };
  }
}

/** Format a raw token amount to PANGU2 (18 decimals, max 4 fractional digits) */
function formatToken(raw: unknown): FormattedAmount {
  try {
    const s = validateAmount(raw);
    if (s === "0") return { valid: true, text: `0 ${TOKEN_SYMBOL}` };
    const len = s.length;
    if (len <= TOKEN_DECIMALS) {
      const frac = s.padStart(TOKEN_DECIMALS, "0");
      const trimmed = frac.slice(0, 4).replace(/0+$/, "");
      return { valid: true, text: trimmed.length > 0 ? `0.${trimmed} ${TOKEN_SYMBOL}` : `<0.0001 ${TOKEN_SYMBOL}` };
    }
    const intPart = s.slice(0, len - TOKEN_DECIMALS);
    const fracPart = s.slice(len - TOKEN_DECIMALS, len - TOKEN_DECIMALS + 4).replace(/0+$/, "");
    return { valid: true, text: fracPart.length > 0 ? `${intPart}.${fracPart} ${TOKEN_SYMBOL}` : `${intPart} ${TOKEN_SYMBOL}` };
  } catch (e: unknown) {
    return { valid: false, text: "\u2014", reason: e instanceof Error ? e.message : "format error" };
  }
}

function fmt(raw: unknown): string {
  return (raw as FormattedAmount).text;
}

async function fetchBuybacks() {
  loadingBuybacks.value = true;
  buybackError.value = null;
  try {
    const res = await fetch(`${PUBLIC_API}/buybacks?page=1&per_page=20`);
    const body = await res.json();
    if (!res.ok || body.error) throw new Error(body.error?.message ?? `HTTP ${res.status}`);
    buybacks.value = Array.isArray(body.data) ? body.data : [];
    buybacksTotal.value = body.meta?.total ?? 0;
  } catch (e: unknown) {
    buybackError.value = e instanceof Error ? e.message : "Failed to load buybacks";
  } finally {
    loadingBuybacks.value = false;
  }
}

async function fetchBatches() {
  loadingBatches.value = true;
  batchError.value = null;
  try {
    const res = await fetch(`${PUBLIC_API}/locker/batches?page=1&per_page=20`);
    const body = await res.json();
    if (!res.ok || body.error) throw new Error(body.error?.message ?? `HTTP ${res.status}`);
    batches.value = Array.isArray(body.data) ? body.data : [];
    batchesTotal.value = body.meta?.total ?? 0;
  } catch (e: unknown) {
    batchError.value = e instanceof Error ? e.message : "Failed to load batches";
  } finally {
    loadingBatches.value = false;
  }
}

onMounted(() => {
  fetchBuybacks();
  fetchBatches();
});

const noData = "\u2014";
</script>

<template>
  <div>
    <div class="hero">
      <div>
        <h3>Buyback &amp; Locker</h3>
        <p>Support fee tokens are converted to BNB, then used for 0.01 BNB buybacks locked for 365 days.</p>
      </div>
      <div class="hero-side">
        <strong>{{ buybacksTotal }}</strong>
        <small>buyback events</small>
      </div>
    </div>

    <div class="section-head"><h3>Buyback Batches</h3></div>
    <div class="card">
      <div class="card-body">
        <div v-if="loadingBuybacks" class="empty-state"><b>Loading...</b></div>
        <div v-else-if="buybackError" class="empty-state error">
          <b>Error</b><small>{{ buybackError }}</small>
          <button class="btn-text" @click="fetchBuybacks">Retry</button>
        </div>
        <div v-else-if="buybacks.length === 0" class="empty-state">
          <b>No buyback batches yet</b>
          <small>Data will appear once the chain worker confirms on-chain buyback events.</small>
        </div>
        <div v-else class="table">
          <div class="tr head"><span>Batch</span><span>BNB</span><span>Tokens</span><span>Time</span></div>
          <div v-for="b in buybacks" :key="b.batch_id" class="tr">
            <span>#{{ b.batch_id }}</span>
            <span>{{ fmt(formatBnb(b.amount_bnb_wei)) }}</span>
            <span>{{ fmt(formatToken(b.tokens_raw)) }}</span>
            <span>{{ b.timestamp }}</span>
          </div>
        </div>
      </div>
    </div>

    <div class="section-head"><h3>Locker Batches</h3></div>
    <div class="card">
      <div class="card-body">
        <div v-if="loadingBatches" class="empty-state"><b>Loading...</b></div>
        <div v-else-if="batchError" class="empty-state error">
          <b>Error</b><small>{{ batchError }}</small>
          <button class="btn-text" @click="fetchBatches">Retry</button>
        </div>
        <div v-else-if="batches.length === 0" class="empty-state">
          <b>No locker batches yet</b>
          <small>Locked tokens will appear once buybacks are executed and confirmed.</small>
        </div>
        <div v-else class="table">
          <div class="tr head"><span>Batch</span><span>Tokens</span><span>Locked Until</span><span>Status</span></div>
          <div v-for="b in batches" :key="b.batch_id" class="tr">
            <span>#{{ b.batch_id }}</span>
            <span>{{ fmt(formatToken(b.tokens_raw)) }}</span>
            <span>{{ b.locked_until ?? noData }}</span>
            <span>{{ b.status }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.hero { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 20px; align-items: end; padding: 22px; border: 1px solid rgba(214,173,95,.22); background: linear-gradient(135deg, rgba(214,173,95,.11), rgba(17,19,24,.96) 48%, rgba(17,19,24,.78)); }
.hero h3 { font-size: 24px; margin: 0; font-weight: 740; }
.hero p { color: var(--muted); font-size: 12px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { color: var(--muted); font-size: 10px; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }
.table { min-width: 600px; overflow: auto; }
.tr { display: grid; grid-template-columns: repeat(4, minmax(100px, 1fr)); gap: 12px; align-items: center; min-height: 48px; padding: 8px 14px; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.tr.head { min-height: 38px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
.empty-state { padding: 24px; text-align: center; }
.empty-state b { display: block; color: var(--muted); }
.empty-state small { display: block; color: var(--muted); margin-top: 6px; font-size: 11px; }
.empty-state.error b { color: var(--red); }
.empty-state.error small { color: var(--red); margin-bottom: 8px; }
.btn-text { border: 0; background: none; color: var(--cyan); font-size: 11px; cursor: pointer; margin-top: 8px; }
</style>
