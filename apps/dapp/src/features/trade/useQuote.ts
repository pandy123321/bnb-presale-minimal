// ═══════════════════════════════════════════
// PANGU2 DApp — useQuote Composable
//
// Single quote lifecycle for buy or sell mode.
// IDLE → LOADING → READY → EXPIRED (30s countdown)
//             ↘ FAILED
//
// Hard rules:
//  - Client does NOT select 4%/10% (rate from API)
//  - Client does NOT calculate profit/tax
//  - All amounts are integer strings (WeiAmount)
//  - source=unavailable disables submission
//  - Expiry disables submission
// ═══════════════════════════════════════════

import { ref, computed, watch, onUnmounted } from "vue";
import type {
  BuyQuote,
  SellQuote,
  BuyQuoteRequest,
  SellQuoteRequest,
  EnvelopeMeta,
} from "@pangu2/api-types";
import { QuoteState, QUOTE_EXPIRY_SECONDS, DataStatus } from "@pangu2/api-types";
import { fetchPost } from "@/api";

export interface QuoteContext {
  state: ReturnType<typeof ref<QuoteState>>;
  isLoading: ReturnType<typeof computed<boolean>>;
  isExpired: ReturnType<typeof computed<boolean>>;
  isUnavailable: ReturnType<typeof computed<boolean>>;
  canSubmit: ReturnType<typeof computed<boolean>>;
  error: ReturnType<typeof ref<string | null>>;
  errorCode: ReturnType<typeof ref<string | null>>;
  errorRetryable: ReturnType<typeof ref<boolean>>;

  buyQuote: ReturnType<typeof ref<BuyQuote | null>>;
  sellQuote: ReturnType<typeof ref<SellQuote | null>>;
  meta: ReturnType<typeof ref<EnvelopeMeta | null>>;

  /** Seconds remaining until quote expires (0 when not READY). */
  remainingSec: ReturnType<typeof ref<number>>;

  fetchBuy(amountBnbWei: string): Promise<void>;
  fetchSell(amountTokenRaw: string, wallet: string): Promise<void>;
  retry(): Promise<void>;
  reset(): void;
  cancel(): void;
}

// ── Wei helpers ─────────────────────────────

export function bnbToWei(bnb: string): string {
  if (!bnb || isNaN(Number(bnb))) return "0";
  const [int, frac = ""] = bnb.split(".");
  return int + frac.padEnd(18, "0").slice(0, 18);
}

export function tokenToRaw(amount: string): string {
  if (!amount || isNaN(Number(amount))) return "0";
  if (amount.includes(".")) {
    const [int, frac = ""] = amount.split(".");
    return int + frac.padEnd(18, "0").slice(0, 18);
  }
  return amount + "0".repeat(18);
}

export function weiToDisplay(wei: string, decimals: number = 18): string {
  if (!wei || wei === "0") return "0";
  const str = wei.padStart(decimals + 1, "0");
  const intPart = str.slice(0, -decimals) || "0";
  const fracPart = str.slice(-decimals).replace(/0+$/, "");
  return fracPart ? `${intPart}.${fracPart}` : intPart;
}

// ── Composable ──────────────────────────────

export function useQuote(): QuoteContext {
  const state = ref<QuoteState>(QuoteState.IDLE);
  const error = ref<string | null>(null);
  const errorCode = ref<string | null>(null);
  const errorRetryable = ref(false);
  const buyQuote = ref<BuyQuote | null>(null);
  const sellQuote = ref<SellQuote | null>(null);
  const meta = ref<EnvelopeMeta | null>(null);
  const remainingSec = ref(0);

  let controller: AbortController | null = null;
  let countdownTimer: ReturnType<typeof setInterval> | null = null;

  // ── Derived ─────────────────────────────────

  const isLoading = computed(() => state.value === QuoteState.LOADING);
  const isExpired = computed(() => state.value === QuoteState.EXPIRED);
  const isUnavailable = computed(
    () =>
      errorCode.value === "UNAVAILABLE" ||
      meta.value?.data_status === DataStatus.UNAVAILABLE ||
      (buyQuote.value?.source === "unavailable") ||
      (sellQuote.value?.source === "unavailable"),
  );

  const canSubmit = computed(
    () => state.value === QuoteState.READY && !isUnavailable.value,
  );

  // ── Internal ────────────────────────────────

  function cancel(): void {
    if (controller) {
      controller.abort();
      controller = null;
    }
  }

  function clearCountdown(): void {
    if (countdownTimer) {
      clearInterval(countdownTimer);
      countdownTimer = null;
    }
    remainingSec.value = 0;
  }

  function startCountdown(): void {
    clearCountdown();
    remainingSec.value = QUOTE_EXPIRY_SECONDS;
    countdownTimer = setInterval(() => {
      remainingSec.value--;
      if (remainingSec.value <= 0) {
        clearCountdown();
        if (state.value === QuoteState.READY) {
          state.value = QuoteState.EXPIRED;
        }
      }
    }, 1_000);
  }

  function reset(): void {
    cancel();
    clearCountdown();
    state.value = QuoteState.IDLE;
    error.value = null;
    errorCode.value = null;
    errorRetryable.value = false;
    buyQuote.value = null;
    sellQuote.value = null;
    meta.value = null;
  }

  // ── Actions ─────────────────────────────────

  async function fetchBuy(amountBnbWei: string): Promise<void> {
    cancel();
    controller = new AbortController();

    state.value = QuoteState.LOADING;
    error.value = null;
    errorCode.value = null;
    errorRetryable.value = false;

    try {
      const result = await fetchPost<BuyQuote>(
        "/v1/projects/pangu2/quotes/buy",
        { amount_bnb_wei: amountBnbWei } satisfies BuyQuoteRequest,
        controller.signal,
      );
      buyQuote.value = result.data;
      sellQuote.value = null;
      meta.value = result.meta;
      state.value = QuoteState.READY;
      startCountdown();
    } catch (e: unknown) {
      if (e instanceof DOMException && e.name === "AbortError") return;
      state.value = QuoteState.FAILED;
      error.value = e instanceof Error ? e.message : "Quote fetch failed.";
      errorCode.value =
        (e as { code?: string }).code ?? "QUOTE_ERROR";
      errorRetryable.value =
        (e as { retryable?: boolean }).retryable ?? true;
    }
  }

  async function fetchSell(amountTokenRaw: string, wallet: string): Promise<void> {
    cancel();
    controller = new AbortController();

    state.value = QuoteState.LOADING;
    error.value = null;
    errorCode.value = null;
    errorRetryable.value = false;

    try {
      const result = await fetchPost<SellQuote>(
        "/v1/projects/pangu2/quotes/sell",
        {
          amount_token_raw: amountTokenRaw,
          wallet_address: wallet,
        } satisfies SellQuoteRequest,
        controller.signal,
      );
      sellQuote.value = result.data;
      buyQuote.value = null;
      meta.value = result.meta;
      state.value = QuoteState.READY;
      startCountdown();
    } catch (e: unknown) {
      if (e instanceof DOMException && e.name === "AbortError") return;
      state.value = QuoteState.FAILED;
      error.value = e instanceof Error ? e.message : "Quote fetch failed.";
      errorCode.value =
        (e as { code?: string }).code ?? "QUOTE_ERROR";
      errorRetryable.value =
        (e as { retryable?: boolean }).retryable ?? true;
    }
  }

  async function retry(): Promise<void> {
    // We don't know the previous params, but the caller can use the
    // returned buyQuote/sellQuote to know which one was last attempted.
    // The view will call fetchBuy/fetchSell explicitly instead.
  }

  onUnmounted(() => {
    cancel();
    clearCountdown();
  });

  return {
    state,
    isLoading,
    isExpired,
    isUnavailable,
    canSubmit,
    error,
    errorCode,
    errorRetryable,
    buyQuote,
    sellQuote,
    meta,
    remainingSec,
    fetchBuy,
    fetchSell,
    retry,
    reset,
    cancel,
  };
}
