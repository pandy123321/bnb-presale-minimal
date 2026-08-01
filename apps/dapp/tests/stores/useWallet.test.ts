// ═══════════════════════════════════════════
// PANGU2 DApp — Wallet Store Unit Tests
//
// Covers: state machine transitions, network detection,
//         computed values, edge cases.
// ═══════════════════════════════════════════

import { describe, it, expect, beforeEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";

// Mock wagmi BEFORE importing the store
const mockGetAccount = vi.fn();
const mockConnect = vi.fn();
const mockDisconnectFn = vi.fn();
const mockSwitchChain = vi.fn();
const mockWatchAccount = vi.fn();
const mockWatchChainId = vi.fn();
const mockReconnect = vi.fn();

vi.mock("@wagmi/core", () => ({
  getAccount: (...args: unknown[]) => mockGetAccount(...args),
  connect: (...args: unknown[]) => mockConnect(...args),
  disconnect: (...args: unknown[]) => mockDisconnectFn(...args),
  switchChain: (...args: unknown[]) => mockSwitchChain(...args),
  watchAccount: (...args: unknown[]) => mockWatchAccount(...args),
  watchChainId: (...args: unknown[]) => mockWatchChainId(...args),
  reconnect: (...args: unknown[]) => mockReconnect(...args),
}));

vi.mock("@wagmi/connectors", () => ({
  injected: vi.fn(() => ({ id: "injected", name: "Injected" })),
}));

// Mock the wagmi config to avoid side effects
vi.mock("@/features/wallet/config", () => ({
  wagmiConfig: {} as never,
  SUPPORTED_CHAIN_IDS: [31337, 97],
  CHAIN_LABELS: {
    31337: { name: "Anvil", env: "LOCAL" },
    97: { name: "BSC Testnet", env: "BSC_TESTNET" },
    56: { name: "BSC Mainnet", env: "MAINNET" },
  },
  isSupportedChain: (id: number | null | undefined) =>
    id != null && [31337, 97].includes(id),
}));

import { useWalletStore } from "@/stores/useWallet";
import { WalletState, NetworkState } from "@pangu2/api-types";

// ── Helpers ─────────────────────────────────────────────────────────

/** Create a mock wagmi account object matching GetAccountReturnType shape. */
function mockAccount(overrides: Partial<{
  address: string;
  chainId: number;
  isConnected: boolean;
}> = {}) {
  return {
    address: overrides.address ?? null,
    addresses: overrides.address ? [overrides.address] : [],
    chainId: overrides.chainId ?? null,
    chain: null,
    connector: { id: "injected", name: "Injected" },
    isConnected: overrides.isConnected ?? (overrides.address != null),
    isConnecting: false,
    isDisconnected: overrides.address == null,
    isReconnecting: false,
    status: overrides.address ? "connected" : "disconnected",
  };
}

// ── Tests ───────────────────────────────────────────────────────────

describe("useWalletStore", () => {
  beforeEach(() => {
    // Fresh Pinia instance per test
    setActivePinia(createPinia());

    // Reset all mocks
    vi.clearAllMocks();

    // Default: not connected
    mockGetAccount.mockReturnValue(mockAccount({ isConnected: false }));
    mockReconnect.mockResolvedValue(undefined);
    mockWatchAccount.mockReturnValue(() => {});
    mockWatchChainId.mockReturnValue(() => {});
  });

  // ═══════════════════════════════════════════
  // 1. Initial state
  // ═══════════════════════════════════════════

  it("starts in DISCONNECTED state with no address", () => {
    const store = useWalletStore();

    expect(store.walletState).toBe(WalletState.DISCONNECTED);
    expect(store.isConnected).toBe(false);
    expect(store.isConnecting).toBe(false);
    expect(store.isDisconnected).toBe(true);
    expect(store.address).toBeNull();
    expect(store.chainId).toBeNull();
    expect(store.shortAddress).toBe("");
    expect(store.error).toBeNull();
  });

  it("starts with UNKNOWN network state", () => {
    const store = useWalletStore();

    expect(store.networkState).toBe(NetworkState.UNKNOWN);
    expect(store.isNetworkSupported).toBe(false);
    expect(store.isNetworkUnsupported).toBe(false);
    expect(store.canTransact).toBe(false);
  });

  // ═══════════════════════════════════════════
  // 2. State machine: DISCONNECTED → CONNECTING
  // ═══════════════════════════════════════════

  it("transitions to CONNECTING when connect() is called", async () => {
    // Don't resolve immediately — stay in CONNECTING
    mockConnect.mockReturnValue(new Promise(() => {}));

    const store = useWalletStore();
    store.connect();

    // Should be connecting now
    await vi.waitFor(() => {
      expect(store.walletState).toBe(WalletState.CONNECTING);
      expect(store.isConnecting).toBe(true);
      expect(store.isDisconnected).toBe(false);
    });
  });

  it("does not re-enter CONNECTING if already CONNECTING", async () => {
    mockConnect.mockReturnValue(new Promise(() => {}));

    const store = useWalletStore();
    store.connect();
    store.connect(); // second call should be ignored

    await vi.waitFor(() => {
      expect(store.walletState).toBe(WalletState.CONNECTING);
    });
    expect(mockConnect).toHaveBeenCalledTimes(1);
  });

  // ═══════════════════════════════════════════
  // 3. State machine: CONNECTING → CONNECTED
  // ═══════════════════════════════════════════

  it("transitions to CONNECTED on successful connection", async () => {
    mockConnect.mockResolvedValue({
      accounts: ["0x1234567890abcdef1234567890abcdef12345678"],
      chainId: 31337,
    });

    const store = useWalletStore();
    await store.connect();

    // connect() resolved; the mock getAccount still returns disconnected
    // because we mocked getAccount separately. The real store relies on
    // watchAccount to fire, which we stub.
    // We simulate the watchAccount callback manually:

    // Simulate wagmi firing account change callback
    const watchCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (watchCb) {
      watchCb(mockAccount({
        address: "0x1234567890abcdef1234567890abcdef12345678",
        chainId: 31337,
        isConnected: true,
      }));
    }

    expect(store.walletState).toBe(WalletState.CONNECTED);
    expect(store.isConnected).toBe(true);
    expect(store.address).toBe("0x1234567890abcdef1234567890abcdef12345678");
    expect(store.shortAddress).toBe("0x1234...5678");
    expect(store.error).toBeNull();
  });

  // ═══════════════════════════════════════════
  // 4. State machine: CONNECTING → ERROR
  // ═══════════════════════════════════════════

  it("transitions to ERROR when user rejects connection", async () => {
    mockConnect.mockRejectedValue({ code: "4001", message: "User rejected" });

    const store = useWalletStore();
    await store.connect();

    expect(store.walletState).toBe(WalletState.ERROR);
    expect(store.hasError).toBe(true);
    expect(store.isConnected).toBe(false);
    expect(store.error).toContain("rejected");
  });

  it("transitions to ERROR when no wallet is detected", async () => {
    mockConnect.mockRejectedValue(new Error("Wallet not detected"));

    const store = useWalletStore();
    await store.connect();

    expect(store.walletState).toBe(WalletState.ERROR);
    expect(store.error).toContain("wallet");
  });

  it("transitions to ERROR on unknown connection failure", async () => {
    mockConnect.mockRejectedValue(new Error("Something went wrong"));

    const store = useWalletStore();
    await store.connect();

    expect(store.walletState).toBe(WalletState.ERROR);
    expect(store.error).toBe("Something went wrong");
  });

  // ═══════════════════════════════════════════
  // 5. Disconnect
  // ═══════════════════════════════════════════

  it("transitions from CONNECTED to DISCONNECTED", async () => {
    // Set up connected state first
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xabcd000000000000000000000000000000000000",
      chainId: 97,
    }));

    const store = useWalletStore();

    // Simulate watchAccount callback to put it in CONNECTED
    const watchCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (watchCb) {
      watchCb(mockAccount({
        address: "0xabcd000000000000000000000000000000000000",
        chainId: 97,
        isConnected: true,
      }));
    }

    expect(store.isConnected).toBe(true);

    // Now disconnect
    mockDisconnectFn.mockResolvedValue(undefined);
    await store.disconnect();

    expect(store.walletState).toBe(WalletState.DISCONNECTED);
    expect(store.isConnected).toBe(false);
    expect(store.address).toBeNull();
    expect(store.chainId).toBeNull();
    expect(store.networkState).toBe(NetworkState.UNKNOWN);
  });

  // ═══════════════════════════════════════════
  // 6. Network states
  // ═══════════════════════════════════════════

  it("detects SUPPORTED network (chain 97)", async () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xtest000000000000000000000000000000000000",
      chainId: 97,
    }));

    const store = useWalletStore();

    const watchCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (watchCb) {
      watchCb(mockAccount({
        address: "0xtest000000000000000000000000000000000000",
        chainId: 97,
        isConnected: true,
      }));
    }

    expect(store.networkState).toBe(NetworkState.SUPPORTED);
    expect(store.isNetworkSupported).toBe(true);
    expect(store.isNetworkUnsupported).toBe(false);
    expect(store.canTransact).toBe(true);
  });

  it("detects UNSUPPORTED network (chain 1)", async () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xtest000000000000000000000000000000000000",
      chainId: 1, // Ethereum mainnet — not supported
    }));

    const store = useWalletStore();

    const watchCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (watchCb) {
      watchCb(mockAccount({
        address: "0xtest000000000000000000000000000000000000",
        chainId: 1,
        isConnected: true,
      }));
    }

    expect(store.networkState).toBe(NetworkState.UNSUPPORTED);
    expect(store.isNetworkUnsupported).toBe(true);
    expect(store.isNetworkSupported).toBe(false);
    expect(store.canTransact).toBe(false); // canTransact requires SUPPORTED network
  });

  it("transitions to SWITCHING and then SUPPORTED on chain switch", async () => {
    // First set up on unsupported chain
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xtest000000000000000000000000000000000000",
      chainId: 1,
    }));

    const store = useWalletStore();

    const acctWatchCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (acctWatchCb) {
      acctWatchCb(mockAccount({
        address: "0xtest000000000000000000000000000000000000",
        chainId: 1,
        isConnected: true,
      }));
    }

    expect(store.networkState).toBe(NetworkState.UNSUPPORTED);

    // Now switch
    mockSwitchChain.mockResolvedValue(undefined);
    const switchPromise = store.switchToSupportedChain();

    // Should be SWITCHING while in flight
    expect(store.networkState).toBe(NetworkState.SWITCHING);
    expect(store.isSwitchingNetwork).toBe(true);

    await switchPromise;

    // Simulate chain change callback
    const chainCb = mockWatchChainId.mock.calls[0]?.[1]?.onChange;
    if (chainCb) {
      chainCb(31337);
    }

    expect(store.networkState).toBe(NetworkState.SUPPORTED);
    expect(store.isSwitchingNetwork).toBe(false);
  });

  it("handles chain switch failure gracefully", async () => {
    mockSwitchChain.mockRejectedValue(new Error("User rejected switch"));

    const store = useWalletStore();
    await store.switchToSupportedChain();

    expect(store.networkState).toBe(NetworkState.ERROR);
    expect(store.error).toContain("User rejected switch");
  });

  // ═══════════════════════════════════════════
  // 7. Computed values
  // ═══════════════════════════════════════════

  it("canTransact is false when DISCONNECTED", () => {
    const store = useWalletStore();

    expect(store.canTransact).toBe(false);
  });

  it("canTransact is false when connected but on UNSUPPORTED network", async () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xtest000000000000000000000000000000000000",
      chainId: 137, // Polygon — not supported
    }));

    const store = useWalletStore();

    const acctCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (acctCb) {
      acctCb(mockAccount({
        address: "0xtest000000000000000000000000000000000000",
        chainId: 137,
        isConnected: true,
      }));
    }

    expect(store.isConnected).toBe(true);
    expect(store.canTransact).toBe(false);
  });

  it("canTransact is true only when CONNECTED + SUPPORTED", async () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xgood00000000000000000000000000000000000",
      chainId: 97,
    }));

    const store = useWalletStore();

    const acctCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (acctCb) {
      acctCb(mockAccount({
        address: "0xgood00000000000000000000000000000000000",
        chainId: 97,
        isConnected: true,
      }));
    }

    expect(store.isConnected).toBe(true);
    expect(store.isNetworkSupported).toBe(true);
    expect(store.canTransact).toBe(true);
  });

  it("shortAddress returns empty string when disconnected", () => {
    const store = useWalletStore();

    expect(store.shortAddress).toBe("");
  });

  it("chainName and environment reflect current chain", async () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xenvtest0000000000000000000000000000000",
      chainId: 97,
    }));

    const store = useWalletStore();

    const acctCb = mockWatchAccount.mock.calls[0]?.[1]?.onChange;
    if (acctCb) {
      acctCb(mockAccount({
        address: "0xenvtest0000000000000000000000000000000",
        chainId: 97,
        isConnected: true,
      }));
    }

    expect(store.chainName).toBe("BSC Testnet");
    expect(store.environment).toBe("BSC_TESTNET");
  });

  // ═══════════════════════════════════════════
  // 8. Error recovery
  // ═══════════════════════════════════════════

  it("clearError clears the error but keeps ERROR state", async () => {
    mockConnect.mockRejectedValue(new Error("Test error"));

    const store = useWalletStore();
    await store.connect();

    expect(store.hasError).toBe(true);
    expect(store.error).toBe("Test error");

    store.clearError();

    expect(store.error).toBeNull();
    // State remains ERROR because the wallet is still not connected
    expect(store.walletState).toBe(WalletState.ERROR);
  });

  it("can retry connection after error", async () => {
    // First attempt fails
    mockConnect.mockRejectedValueOnce(new Error("First failure"));
    const store = useWalletStore();
    await store.connect();
    expect(store.walletState).toBe(WalletState.ERROR);

    // Clear and retry
    store.clearError();

    // Second attempt succeeds
    mockConnect.mockResolvedValueOnce({
      accounts: ["0xretry00000000000000000000000000000000000"],
      chainId: 31337,
    });
    await store.connect();

    expect(mockConnect).toHaveBeenCalledTimes(2);
  });

  // ═══════════════════════════════════════════
  // 9. Page refresh / reconnect
  // ═══════════════════════════════════════════

  it("restores session on page load via getAccount", () => {
    mockGetAccount.mockReturnValue(mockAccount({
      address: "0xexisting0000000000000000000000000000000",
      chainId: 31337,
      isConnected: true,
    }));

    const store = useWalletStore();

    // Should be CONNECTED immediately from getAccount sync result
    expect(store.walletState).toBe(WalletState.CONNECTED);
    expect(store.address).toBe("0xexisting0000000000000000000000000000000");
    expect(store.chainId).toBe(31337);
    expect(store.networkState).toBe(NetworkState.SUPPORTED);
  });

  it("recovers from getAccount throw during init", () => {
    mockGetAccount.mockImplementation(() => {
      throw new Error("Not initialized");
    });

    const store = useWalletStore();

    // Should gracefully fall back to DISCONNECTED
    expect(store.walletState).toBe(WalletState.DISCONNECTED);
  });
});
