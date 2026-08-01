// ═══════════════════════════════════════════
// PANGU2 DApp — Wallet Store (Pinia)
//
// State machine:  DISCONNECTED → CONNECTING → (CONNECTED | ERROR)
// Network states: UNKNOWN → (SUPPORTED | UNSUPPORTED) → SWITCHING → ...
//
// Hard rules:
//  - User asset operations require wallet signature (CONNECTED required)
//  - Wrong network prevents trading (UNSUPPORTED blocks actions)
//  - Never stores private keys
//  - All mock data explicitly marked MOCK_DATA
// ═══════════════════════════════════════════

import { defineStore } from "pinia";
import { ref, computed, shallowRef, markRaw } from "vue";
import {
  connect,
  disconnect as wagmiDisconnect,
  switchChain,
  getAccount,
  watchAccount,
  watchChainId,
  reconnect,
} from "@wagmi/core";
import { injected } from "@wagmi/connectors";
import type { Connector } from "@wagmi/core";

import { wagmiConfig, SUPPORTED_CHAIN_IDS, CHAIN_LABELS, isSupportedChain } from "@/features/wallet/config";
import { WalletState, NetworkState } from "@pangu2/api-types";

// ── Helpers ─────────────────────────────────────────────────────────

function shortAddr(address: string | null): string {
  if (!address) return "";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function chainLabel(chainId: number | null): string {
  if (chainId == null) return "Unknown";
  return CHAIN_LABELS[chainId]?.name ?? `Chain ${chainId}`;
}

function chainEnv(chainId: number | null): string {
  if (chainId == null) return "UNKNOWN";
  return CHAIN_LABELS[chainId]?.env ?? "UNKNOWN";
}

// ── Store ───────────────────────────────────────────────────────────

export const useWalletStore = defineStore("wallet", () => {
  // ═══════════════════════════════════════════
  // Core reactive state
  // ═══════════════════════════════════════════
  const walletState = ref<WalletState>(WalletState.DISCONNECTED);
  const networkState = ref<NetworkState>(NetworkState.UNKNOWN);
  const address = ref<string | null>(null);
  const chainId = ref<number | null>(null);
  const connector = shallowRef<Connector | null>(null);
  const error = ref<string | null>(null);

  // ═══════════════════════════════════════════
  // Derived / computed
  // ═══════════════════════════════════════════

  const isConnected = computed(() => walletState.value === WalletState.CONNECTED);
  const isConnecting = computed(() => walletState.value === WalletState.CONNECTING);
  const isDisconnected = computed(() => walletState.value === WalletState.DISCONNECTED);
  const hasError = computed(() => walletState.value === WalletState.ERROR);

  const isNetworkSupported = computed(
    () => networkState.value === NetworkState.SUPPORTED,
  );
  const isNetworkUnsupported = computed(
    () => networkState.value === NetworkState.UNSUPPORTED,
  );
  const isSwitchingNetwork = computed(
    () => networkState.value === NetworkState.SWITCHING,
  );

  const shortAddress = computed(() => shortAddr(address.value));
  const chainName = computed(() => chainLabel(chainId.value));
  const environment = computed(() => chainEnv(chainId.value));

  /** Whether the user can send transactions now. */
  const canTransact = computed(
    () => walletState.value === WalletState.CONNECTED
      && networkState.value === NetworkState.SUPPORTED,
  );

  // ═══════════════════════════════════════════
  // Internal — sync helpers
  // ═══════════════════════════════════════════

  function syncAccount(): void {
    const acct = getAccount(wagmiConfig);
    if (acct.isConnected && acct.address) {
      address.value = acct.address;
      chainId.value = acct.chainId ?? null;
      connector.value = markRaw(acct.connector ?? null);
      walletState.value = WalletState.CONNECTED;
      syncNetwork(acct.chainId ?? null);
    }
  }

  function syncNetwork(cId: number | null | undefined): void {
    if (cId == null) {
      networkState.value = NetworkState.UNKNOWN;
      return;
    }
    chainId.value = cId;
    networkState.value = isSupportedChain(cId)
      ? NetworkState.SUPPORTED
      : NetworkState.UNSUPPORTED;
  }

  function clearError(): void {
    error.value = null;
  }

  function setError(msg: string): void {
    error.value = msg;
    walletState.value = WalletState.ERROR;
  }

  // ═══════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════

  async function connectWallet(): Promise<void> {
    if (walletState.value === WalletState.CONNECTING) return;

    clearError();
    walletState.value = WalletState.CONNECTING;

    try {
      const result = await connect(wagmiConfig, { connector: injected() });
      // watchAccount handler will pick up the change and set CONNECTED
      if (!result.accounts?.length) {
        setError("No accounts returned from wallet.");
      }
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string };
      if (err.code === "4001" || err.message?.includes("rejected")) {
        setError("Connection rejected. Please approve in your wallet.");
      } else if (err.message?.includes("not found") || err.message?.includes("not detected")) {
        setError("No wallet detected. Please install MetaMask or a compatible wallet.");
      } else {
        setError(err.message ?? "Unknown connection error.");
      }
    }
  }

  async function disconnectWallet(): Promise<void> {
    try {
      await wagmiDisconnect(wagmiConfig);
    } finally {
      address.value = null;
      chainId.value = null;
      connector.value = null;
      error.value = null;
      walletState.value = WalletState.DISCONNECTED;
      networkState.value = NetworkState.UNKNOWN;
    }
  }

  async function switchToSupportedChain(): Promise<void> {
    if (!SUPPORTED_CHAIN_IDS.length) return;
    networkState.value = NetworkState.SWITCHING;

    try {
      const target = SUPPORTED_CHAIN_IDS[0];
      await switchChain(wagmiConfig, { chainId: target });
      // watchChainId handler picks up the change → networkState → SUPPORTED
    } catch (e: unknown) {
      const err = e as { message?: string };
      setError(err.message ?? "Network switch failed.");
      networkState.value = NetworkState.ERROR;
    }
  }

  /**
   * For backward-compat with existing views that call `openConnectSheet()`.
   * Emits an event so the ConnectSheet can respond.
   */
  function openConnectSheet(): void {
    connectWallet();
  }

  // ═══════════════════════════════════════════
  // Watchers — set up once on first store access
  // ═══════════════════════════════════════════

  let watchersSetup = false;

  function setupWatchers(): void {
    if (watchersSetup) return;
    watchersSetup = true;

    // Account changes (connect, disconnect, account switch)
    watchAccount(wagmiConfig, {
      onChange(acct) {
        if (acct.isConnected && acct.address) {
          address.value = acct.address;
          connector.value = markRaw(acct.connector ?? null);
          walletState.value = WalletState.CONNECTED;
          error.value = null;
        } else {
          address.value = null;
          connector.value = null;
          walletState.value = WalletState.DISCONNECTED;
        }
        syncNetwork(acct.chainId ?? null);
      },
    });

    // Chain changes (network switch, chain added)
    watchChainId(wagmiConfig, {
      onChange(cId) {
        syncNetwork(cId);
      },
    });
  }

  // ── Boot: sync existing session (page refresh) ──
  try {
    syncAccount();
  } catch {
    // Not connected yet — stay DISCONNECTED
  }

  setupWatchers();

  // ── Attempt silent reconnect on page load ──
  reconnect(wagmiConfig).catch(() => {
    // Silently ignore — user hasn't connected before
  });

  // ═══════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════

  return {
    // state
    walletState,
    networkState,
    address,
    chainId,
    connector,
    error,
    // computed
    isConnected,
    isConnecting,
    isDisconnected,
    hasError,
    isNetworkSupported,
    isNetworkUnsupported,
    isSwitchingNetwork,
    shortAddress,
    chainName,
    environment,
    canTransact,
    // actions
    connect: connectWallet,
    disconnect: disconnectWallet,
    switchToSupportedChain,
    openConnectSheet,
    clearError,
  };
});
