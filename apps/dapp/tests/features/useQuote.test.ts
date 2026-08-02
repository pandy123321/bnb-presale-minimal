// ═══════════════════════════════════════════
// PANGU2 DApp — useQuote Tests
//
// Tests quote lifecycle: IDLE→LOADING→READY→EXPIRED, FAILED, UNAVAILABLE.
// ═══════════════════════════════════════════

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";

// Mock the API client
const mockPost = vi.fn();
vi.mock("@/api", () => ({
  fetchPost: (...args: unknown[]) => mockPost(...args),
  useAsyncData: vi.fn(),
}));

// Mock wagmi
vi.mock("@wagmi/core", () => ({
  connect: vi.fn(),
  disconnect: vi.fn(),
  switchChain: vi.fn(),
  getAccount: vi.fn(() => ({ address: null, chainId: null, isConnected: false })),
  watchAccount: vi.fn(() => () => {}),
  watchChainId: vi.fn(() => () => {}),
  reconnect: vi.fn(() => Promise.resolve()),
}));

vi.mock("@wagmi/connectors", () => ({
  injected: vi.fn(() => ({ id: "injected" })),
}));

vi.mock("@/features/wallet/config", () => ({
  wagmiConfig: {},
  SUPPORTED_CHAIN_IDS: [31337, 97],
  CHAIN_LABELS: {
    31337: { name: "Anvil", env: "LOCAL" },
    97: { name: "BSC Testnet", env: "BSC_TESTNET" },
  },
  isSupportedChain: (id: number | null | undefined) =>
    id != null && [31337, 97].includes(id),
}));

import { nextTick } from "vue";
import { useQuote, bnbToWei, tokenToRaw, weiToDisplay } from "@/features/trade/useQuote";
import { QuoteState, QUOTE_EXPIRY_SECONDS } from "@pangu2/api-types";

// ── Mock response factory ───────────────────

function mockBuyQuote() {
  return {
    data: {
      amount_in_wei: "100000000000000000",
      gross_tokens_raw: "46235000000000000000000",
      tax_rate: "4.00%",
      tax_tokens_raw: "1849400000000000000000",
      net_tokens_raw: "44385600000000000000000",
      min_receive_raw: "43941744000000000000000",
      quote_block: "42815128",
      expires_at: new Date(Date.now() + 30_000).toISOString(),
      source: "mock",
    },
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "MOCK_DATA",
      block_number: "42815128",
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
    },
  };
}

function mockSellQuote() {
  return {
    data: {
      amount_in_raw: "10000000000000000000000",
      gross_bnb_wei: "21630000000000",
      tax_rate: "4%",
      tax_tokens_raw: "400000000000000000000",
      tax_destination: "4%→SupportPool",
      net_bnb_wei: "21400000000000",
      min_receive_wei: "21100000000000",
      quote_block: "42815128",
      expires_at: new Date(Date.now() + 30_000).toISOString(),
      source: "mock",
    },
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "MOCK_DATA",
      block_number: "42815128",
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
    },
  };
}

function mockUnavailableQuote() {
  return {
    data: null,
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "UNAVAILABLE",
      block_number: null,
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
    },
  };
}

// ── Tests ───────────────────────────────────

describe("useQuote", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  // ═══════════════════════════════════════════
  // 1. Wei helpers
  // ═══════════════════════════════════════════

  describe("wei helpers", () => {
    it("bnbToWei converts 0.1 BNB to correct wei", () => {
      expect(bnbToWei("0.1")).toBe("100000000000000000");
    });

    it("bnbToWei handles integer input", () => {
      expect(bnbToWei("3")).toBe("3000000000000000000");
    });

    it("bnbToWei returns '0' for empty input", () => {
      expect(bnbToWei("")).toBe("0");
    });

    it("tokenToRaw converts integer token amount", () => {
      expect(tokenToRaw("10000")).toBe("10000000000000000000000");
    });

    it("weiToDisplay formats wei back to human-readable", () => {
      expect(weiToDisplay("100000000000000000")).toBe("0.1");
    });

    it("weiToDisplay returns '0' for zero wei", () => {
      expect(weiToDisplay("0")).toBe("0");
    });
  });

  // ═══════════════════════════════════════════
  // 2. State machine: IDLE → LOADING → READY
  // ═══════════════════════════════════════════

  it("starts in IDLE state", () => {
    const quote = useQuote();
    expect(quote.state.value).toBe(QuoteState.IDLE);
    expect(quote.buyQuote.value).toBeNull();
    expect(quote.error.value).toBeNull();
    expect(quote.remainingSec.value).toBe(0);
  });

  it("transitions IDLE → LOADING → READY on successful buy fetch", async () => {
    mockPost.mockResolvedValue(mockBuyQuote());
    const quote = useQuote();

    const promise = quote.fetchBuy("100000000000000000");
    expect(quote.state.value).toBe(QuoteState.LOADING);

    await promise;
    expect(quote.state.value).toBe(QuoteState.READY);
    expect(quote.buyQuote.value).not.toBeNull();
    expect(quote.buyQuote.value!.tax_rate).toBe("4.00%");
    expect(quote.meta.value?.data_status).toBe("MOCK_DATA");
  });

  it("loads sell quote with wallet address", async () => {
    mockPost.mockResolvedValue(mockSellQuote());
    const quote = useQuote();

    await quote.fetchSell("10000", "0xaaaa0000000000000000000000000000000000");

    expect(quote.sellQuote.value).not.toBeNull();
    expect(quote.sellQuote.value!.tax_rate).toBe("4%");
    expect(quote.sellQuote.value!.tax_destination).toBe("4%→SupportPool");
  });

  // ═══════════════════════════════════════════
  // 3. IDLE → LOADING → FAILED
  // ═══════════════════════════════════════════

  it("transitions to FAILED on network error", async () => {
    mockPost.mockRejectedValue(new Error("Network error"));
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");

    expect(quote.state.value).toBe(QuoteState.FAILED);
    expect(quote.error.value).toBe("Network error");
    expect(quote.errorRetryable.value).toBe(true);
  });

  it("transitions to FAILED and detects UNAVAILABLE", async () => {
    mockPost.mockRejectedValue({ message: "Quote unavailable", code: "UNAVAILABLE" });
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");

    expect(quote.state.value).toBe(QuoteState.FAILED);
    expect(quote.errorCode.value).toBe("UNAVAILABLE");
    expect(quote.isUnavailable.value).toBe(true);
  });

  // ═══════════════════════════════════════════
  // 4. Countdown timer
  // ═══════════════════════════════════════════

  it("starts countdown on READY and expires after 30 seconds", async () => {
    mockPost.mockResolvedValue(mockBuyQuote());
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");
    expect(quote.remainingSec.value).toBe(QUOTE_EXPIRY_SECONDS);

    vi.advanceTimersByTime(15_000);
    await nextTick();
    expect(quote.remainingSec.value).toBe(15);

    vi.advanceTimersByTime(15_000);
    await nextTick();
    expect(quote.state.value).toBe(QuoteState.EXPIRED);
    expect(quote.remainingSec.value).toBe(0);
    expect(quote.isExpired.value).toBe(true);
    expect(quote.canSubmit.value).toBe(false);
  });

  // ═══════════════════════════════════════════
  // 5. Reset and abort
  // ═══════════════════════════════════════════

  it("reset clears all state back to IDLE", async () => {
    mockPost.mockResolvedValue(mockBuyQuote());
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");
    quote.reset();

    expect(quote.state.value).toBe(QuoteState.IDLE);
    expect(quote.buyQuote.value).toBeNull();
    expect(quote.error.value).toBeNull();
    expect(quote.remainingSec.value).toBe(0);
  });

  // ═══════════════════════════════════════════
  // 6. canSubmit gates
  // ═══════════════════════════════════════════

  it("cannot submit in IDLE state", () => {
    const quote = useQuote();
    expect(quote.canSubmit.value).toBe(false);
  });

  it("cannot submit in LOADING state", async () => {
    mockPost.mockReturnValue(new Promise(() => {})); // never resolves
    const quote = useQuote();

    quote.fetchBuy("100000000000000000");
    expect(quote.canSubmit.value).toBe(false);
  });

  it("can submit in READY state", async () => {
    mockPost.mockResolvedValue(mockBuyQuote());
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");
    expect(quote.canSubmit.value).toBe(true);
  });

  it("cannot submit when source is unavailable", async () => {
    mockPost.mockResolvedValue({
      data: {
        ...mockBuyQuote().data,
        source: "unavailable",
      },
      meta: { ...mockBuyQuote().meta, data_status: "MOCK_DATA" },
    });
    const quote = useQuote();

    await quote.fetchBuy("100000000000000000");
    expect(quote.isUnavailable.value).toBe(true);
    expect(quote.canSubmit.value).toBe(false);
  });

  // ═══════════════════════════════════════════
  // 7. Sell quote gets cleared on buy, and vice versa
  // ═══════════════════════════════════════════

  it("buy quote clears sell quote data", async () => {
    mockPost.mockResolvedValueOnce(mockSellQuote());
    const quote = useQuote();
    await quote.fetchSell("10000", "0xaaaa0000000000000000000000000000000000");
    expect(quote.sellQuote.value).not.toBeNull();

    mockPost.mockResolvedValueOnce(mockBuyQuote());
    await quote.fetchBuy("100000000000000000");
    expect(quote.buyQuote.value).not.toBeNull();
    expect(quote.sellQuote.value).toBeNull();
  });
});
