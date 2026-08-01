// ═══════════════════════════════════════════
// PANGU2 — State Machine Types
// Source: docs/schemas/state-machines/pangu2-state-machines-v1.json
// Used by DApp and Admin for consistent UI state management
// ═══════════════════════════════════════════

// ── Wallet ──
export const WalletState = {
  DISCONNECTED: "DISCONNECTED",
  CONNECTING: "CONNECTING",
  CONNECTED: "CONNECTED",
  ERROR: "ERROR",
} as const;
export type WalletState = (typeof WalletState)[keyof typeof WalletState];

// ── Network ──
export const NetworkState = {
  UNKNOWN: "UNKNOWN",
  SUPPORTED: "SUPPORTED",
  UNSUPPORTED: "UNSUPPORTED",
  SWITCHING: "SWITCHING",
  ERROR: "ERROR",
} as const;
export type NetworkState = (typeof NetworkState)[keyof typeof NetworkState];

// ── Quote ──
export const QuoteState = {
  IDLE: "IDLE",
  LOADING: "LOADING",
  READY: "READY",
  EXPIRED: "EXPIRED",
  FAILED: "FAILED",
} as const;
export type QuoteState = (typeof QuoteState)[keyof typeof QuoteState];

export const QUOTE_EXPIRY_SECONDS = 30;
export const QUOTE_SUBMIT_BLOCKED_IN: QuoteState[] = [
  QuoteState.IDLE,
  QuoteState.LOADING,
  QuoteState.EXPIRED,
  QuoteState.FAILED,
];

// ── Approval ──
export const ApprovalState = {
  NOT_REQUIRED: "NOT_REQUIRED",
  REQUIRED: "REQUIRED",
  SIGNATURE_PENDING: "SIGNATURE_PENDING",
  SUBMITTED: "SUBMITTED",
  CONFIRMED: "CONFIRMED",
  FAILED: "FAILED",
  REJECTED: "REJECTED",
} as const;
export type ApprovalState = (typeof ApprovalState)[keyof typeof ApprovalState];

// ── Chain Transaction ──
export const ChainTxState = {
  CREATED: "CREATED",
  SUBMITTED: "SUBMITTED",
  PENDING: "PENDING",
  CONFIRMED: "CONFIRMED",
  FAILED: "FAILED",
  REPLACED: "REPLACED",
  DROPPED: "DROPPED",
  REORGED: "REORGED",
} as const;
export type ChainTxState = (typeof ChainTxState)[keyof typeof ChainTxState];

export const CHAIN_TX_TERMINAL: ChainTxState[] = [
  ChainTxState.CONFIRMED,
  ChainTxState.FAILED,
  ChainTxState.REPLACED,
  ChainTxState.DROPPED,
  ChainTxState.REORGED,
];

// ── Claim ──
export const ClaimState = {
  NOT_AVAILABLE: "NOT_AVAILABLE",
  AVAILABLE: "AVAILABLE",
  SIGNATURE_PENDING: "SIGNATURE_PENDING",
  SUBMITTED: "SUBMITTED",
  CLAIMED: "CLAIMED",
  FAILED: "FAILED",
  REORG_RECHECK: "REORG_RECHECK",
} as const;
export type ClaimState = (typeof ClaimState)[keyof typeof ClaimState];
