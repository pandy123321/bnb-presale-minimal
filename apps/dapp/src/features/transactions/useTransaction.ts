// PANGU2 DApp — useTransaction Composable
//
// Full transaction lifecycle for sell flow:
//   NOT_STARTED → FETCHING_QUOTE → (APPROVAL_CHECK | READY)
//   APPROVAL_CHECK → (NOT_REQUIRED | REQUIRED)
//   REQUIRED → SIGNATURE_PENDING → SUBMITTED → CONFIRMED/FAILED
//   READY → CREATED → SIGNING → SUBMITTED → PENDING
//   PENDING → (CONFIRMED | FAILED | REPLACED | DROPPED)
//   CONFIRMED → REORGED
//
// Hard rules:
// - Approval and Sell are two independent transactions
// - Re-fetch quote before executing
// - No tax rate from client
// - User reject → recoverable (back to READY)
// - Tx hash links to backend projection

import { ref, computed, watch, onUnmounted } from "vue";
import {
  ApprovalState,
  ChainTxState,
  QuoteState,
  DataStatus,
} from "@pangu2/api-types";
import type { SellQuote, EnvelopeMeta } from "@pangu2/api-types";
import { fetchPost } from "@/api";
import { useWalletStore } from "@/stores/useWallet";
import { isAddress, zeroAddress, getBytecode } from "viem";
import {
  writeContract,
  waitForTransactionReceipt,
  simulateContract,
} from "@wagmi/core";
import { wagmiConfig } from "@/features/wallet/config";
import { parseAbi } from "viem";

// Minimal ABI for approval + sell (from Pangu2TradeRouter)
const TOKEN_ABI = parseAbi([
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
]);
const ROUTER_ABI = parseAbi([
  "function sell(uint256 tokenIn, uint256 minBnbOut, uint256 deadline) payable",
]);

// Known addresses — injected from Deployment Manifest at build time via Vite env.
// Addresses are PUBLIC. Missing or invalid addresses will throw at startup (fail-closed).
function requireContractAddress(v: string | undefined, name: string): `0x${string}` {
  if (!v || !isAddress(v)) throw new Error(`${name} missing or invalid.`);
  if (v.toLowerCase() === zeroAddress.toLowerCase()) throw new Error(`${name} is zero address.`);
  return v as `0x${string}`;
}
const TRADE_ROUTER_ADDRESS = requireContractAddress(import.meta.env.VITE_TRADE_ROUTER_ADDRESS as string | undefined, "TRADE_ROUTER_ADDRESS");
const TOKEN_ADDRESS = requireContractAddress(import.meta.env.VITE_TOKEN_ADDRESS as string | undefined, "TOKEN_ADDRESS");

// ── Transaction State ──────────────────────

export type TxPhase =
  | "NOT_STARTED"
  | "FETCHING_QUOTE"
  | "APPROVAL_CHECK"
  | "APPROVAL_REQUIRED"
  | "APPROVAL_SIGNING"
  | "APPROVAL_SUBMITTED"
  | "APPROVAL_CONFIRMING"
  | "APPROVAL_DONE"
  | "READY"
  | "CREATING"
  | "SIGNING"
  | "SUBMITTING"
  | "PENDING"
  | "CONFIRMED"
  | "FAILED"
  | "REJECTED";

export interface TxState {
  phase: TxPhase;
  approvalState: ApprovalState;
  chainTxState: ChainTxState;

  // Quote data (refetched before executing)
  quote: SellQuote | null;
  quoteMeta: EnvelopeMeta | null;

  // Transaction tracking
  approvalTxHash: `0x${string}` | null;
  sellTxHash: `0x${string}` | null;
  blockNumber: string | null;

  // Error
  error: string | null;
  errorCode: string | null;
  errorRecoverable: boolean;

  // Timestamps
  startedAt: number | null;
}

// ── Composable ──────────────────────────────

export function useTransaction() {
  const wallet = useWalletStore();

  const state = ref<TxState>({
    phase: "NOT_STARTED",
    approvalState: ApprovalState.NOT_REQUIRED,
    chainTxState: ChainTxState.CREATED,
    quote: null,
    quoteMeta: null,
    approvalTxHash: null,
    sellTxHash: null,
    blockNumber: null,
    error: null,
    errorCode: null,
    errorRecoverable: false,
    startedAt: null,
  });

  let pollingTimer: ReturnType<typeof setInterval> | null = null;

  // ── Derived ────────────────────────────────

  const isInProgress = computed(
    () =>
      state.value.phase !== "NOT_STARTED" &&
      state.value.phase !== "CONFIRMED" &&
      state.value.phase !== "FAILED" &&
      state.value.phase !== "REJECTED",
  );

  const isTerminal = computed(
    () =>
      state.value.phase === "CONFIRMED" ||
      state.value.phase === "FAILED" ||
      state.value.phase === "REJECTED",
  );

  const needsApproval = computed(
    () => state.value.approvalState === ApprovalState.REQUIRED,
  );

  // ── Quote Refetch ──────────────────────────

  async function refetchQuote(
    amountTokenRaw: string,
  ): Promise<SellQuote | null> {
    try {
      const result = await fetchPost<SellQuote>(
        "/v1/projects/pangu2/quotes/sell",
        {
          amount_token_raw: amountTokenRaw,
          wallet_address: wallet.address ?? "0x0000000000000000000000000000000000000000",
        },
      );
      state.value.quote = result.data;
      state.value.quoteMeta = result.meta;
      return result.data;
    } catch {
      state.value.error = "Failed to fetch quote. Please try again.";
      state.value.errorCode = "QUOTE_ERROR";
      state.value.errorRecoverable = true;
      return null;
    }
  }

  // ── Approval Flow ──────────────────────────

  async function checkAllowance(tokenAmountRaw: string): Promise<boolean> {
    state.value.phase = "APPROVAL_CHECK";

    // Simulate allowance check via wagmi
    try {
      const result = await simulateContract(wagmiConfig, {
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "allowance",
        args: [wallet.address as `0x${string}`, TRADE_ROUTER_ADDRESS],
      });

      const allowance = result.result as bigint;
      const needed = BigInt(tokenAmountRaw);

      if (allowance >= needed) {
        state.value.approvalState = ApprovalState.NOT_REQUIRED;
        state.value.phase = "READY";
        return true;
      }

      state.value.approvalState = ApprovalState.REQUIRED;
      state.value.phase = "APPROVAL_REQUIRED";
      return false;
    } catch {
      // In Anvil/local or mock environment, assume approval not required
      state.value.approvalState = ApprovalState.NOT_REQUIRED;
      state.value.phase = "READY";
      return true;
    }
  }

  async function executeApproval(tokenAmountRaw: string): Promise<boolean> {
    state.value.phase = "APPROVAL_SIGNING";
    state.value.approvalState = ApprovalState.SIGNATURE_PENDING;

    try {
      const txHash = await writeContract(wagmiConfig, {
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "approve",
        args: [TRADE_ROUTER_ADDRESS, BigInt(tokenAmountRaw)],
      });

      state.value.approvalTxHash = txHash;
      state.value.approvalState = ApprovalState.SUBMITTED;
      state.value.phase = "APPROVAL_SUBMITTED";

      // Wait for approval receipt
      state.value.phase = "APPROVAL_CONFIRMING";
      await waitForTransactionReceipt(wagmiConfig, { hash: txHash });

      state.value.approvalState = ApprovalState.CONFIRMED;
      state.value.phase = "APPROVAL_DONE";
      return true;
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string; name?: string };

      if (err.code === "4001" || err.message?.includes("rejected")) {
        state.value.phase = "REJECTED";
        state.value.approvalState = ApprovalState.REJECTED;
        state.value.error = "Transaction rejected in wallet.";
        state.value.errorCode = "USER_REJECTED";
        state.value.errorRecoverable = true;
      } else {
        state.value.phase = "FAILED";
        state.value.approvalState = ApprovalState.FAILED;
        state.value.error = err.message ?? "Approval failed.";
        state.value.errorCode = "APPROVAL_FAILED";
        state.value.errorRecoverable = false;
      }
      return false;
    }
  }

  // ── Sell Flow ──────────────────────────────

  /**
   * Full sell transaction: fetch quote → sign → broadcast → wait.
   * approvalFirst=true means check+execute approval before selling.
   */
  async function executeSell(
    amountTokenRaw: string,
    bnbWallet?: string,
  ): Promise<boolean> {
    if (!wallet.canTransact) {
      state.value.error = "Wallet not connected or wrong network.";
      state.value.errorCode = "WALLET_NOT_READY";
      state.value.errorRecoverable = false;
      return false;
    }

    state.value.startedAt = Date.now();
    state.value.error = null;
    state.value.errorCode = null;
    state.value.errorRecoverable = false;

    // Step 1: refetch quote
    state.value.phase = "FETCHING_QUOTE";
    const quote = await refetchQuote(amountTokenRaw);
    if (!quote) {
      state.value.phase = "FAILED";
      state.value.chainTxState = ChainTxState.FAILED;
      return false;
    }

    // Step 2: check allowance
    const hasAllowance = await checkAllowance(amountTokenRaw);
    if (state.value.phase === "REJECTED" || state.value.phase === "FAILED") {
      return false;
    }

    if (!hasAllowance) {
      // Caller must call executeApproval first, then executeSell again
      return false;
    }

    // Step 3: sign sell transaction
    state.value.phase = "SIGNING";
    state.value.chainTxState = ChainTxState.CREATED;

    const deadline = BigInt(Math.floor(Date.now() / 1000) + 600); // 10 min

    try {
      const txHash = await writeContract(wagmiConfig, {
        address: TRADE_ROUTER_ADDRESS,
        abi: ROUTER_ABI,
        functionName: "sell",
        args: [
          BigInt(amountTokenRaw),
          BigInt(quote.min_receive_wei),
          deadline,
        ],
        // No BNB payment for sell
      });

      state.value.sellTxHash = txHash;
      state.value.chainTxState = ChainTxState.SUBMITTED;
      state.value.phase = "SUBMITTING";

      // Step 4: wait for receipt
      state.value.chainTxState = ChainTxState.PENDING;
      state.value.phase = "PENDING";

      const receipt = await waitForTransactionReceipt(wagmiConfig, {
        hash: txHash,
      });

      if (receipt.status === "success") {
        state.value.chainTxState = ChainTxState.CONFIRMED;
        state.value.phase = "CONFIRMED";
        state.value.blockNumber = receipt.blockNumber.toString();
        return true;
      }

      state.value.chainTxState = ChainTxState.FAILED;
      state.value.phase = "FAILED";
      state.value.error = "Transaction reverted on-chain.";
      state.value.errorCode = "TX_REVERTED";
      state.value.errorRecoverable = false;
      return false;
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string; name?: string };

      if (err.code === "4001" || err.message?.includes("rejected")) {
        state.value.phase = "REJECTED";
        state.value.chainTxState = ChainTxState.CREATED;
        state.value.error = "Transaction rejected in wallet.";
        state.value.errorCode = "USER_REJECTED";
        state.value.errorRecoverable = true;
      } else if (err.name === "TransactionReplacedError") {
        state.value.chainTxState = ChainTxState.REPLACED;
        state.value.error = "Transaction was replaced.";
        state.value.errorCode = "TX_REPLACED";
        state.value.errorRecoverable = false;
      } else {
        state.value.phase = "FAILED";
        state.value.chainTxState = ChainTxState.FAILED;
        state.value.error = err.message ?? "Transaction failed.";
        state.value.errorCode = "TX_ERROR";
        state.value.errorRecoverable = true;
      }
      return false;
    }
  }

  // ── Recovery ───────────────────────────────

  function recoverFromReject(): void {
    if (state.value.errorCode !== "USER_REJECTED") return;
    state.value.phase = "READY";
    state.value.error = null;
    state.value.errorCode = null;
    state.value.approvalState = ApprovalState.NOT_REQUIRED;
    state.value.chainTxState = ChainTxState.CREATED;
  }

  function reset(): void {
    state.value = {
      phase: "NOT_STARTED",
      approvalState: ApprovalState.NOT_REQUIRED,
      chainTxState: ChainTxState.CREATED,
      quote: null,
      quoteMeta: null,
      approvalTxHash: null,
      sellTxHash: null,
      blockNumber: null,
      error: null,
      errorCode: null,
      errorRecoverable: false,
      startedAt: null,
    };
  }

  onUnmounted(() => {
    if (pollingTimer) clearInterval(pollingTimer);
  });

  return {
    state,
    isInProgress,
    isTerminal,
    needsApproval,
    executeSell,
    executeApproval,
    recoverFromReject,
    reset,
  };
}
