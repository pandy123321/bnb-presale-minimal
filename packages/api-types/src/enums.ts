// ═══════════════════════════════════════════
// PANGU2 — Domain Enums and Constants
// Source: packages/domain/pangu2-domain-v1.json
// ═══════════════════════════════════════════

/** System-wide data status — must be displayed prominently */
export const DataStatus = {
  MOCK_DATA: "MOCK_DATA",
  SYNCING: "SYNCING",
  LIVE: "LIVE",
  STALE: "STALE",
  DEGRADED: "DEGRADED",
  UNAVAILABLE: "UNAVAILABLE",
} as const;
export type DataStatus = (typeof DataStatus)[keyof typeof DataStatus];

export const Environment = {
  LOCAL: "LOCAL",
  CI: "CI",
  BSC_TESTNET: "BSC_TESTNET",
  STAGING: "STAGING",
} as const;
export type Environment = (typeof Environment)[keyof typeof Environment];

export const ChainId = {
  ANVIL: 31337,
  BSC_TESTNET: 97,
  BSC_MAINNET: 56,
} as const;
export type ChainId = (typeof ChainId)[keyof typeof ChainId];

export const TransactionType = {
  BUY: "buy",
  SELL: "sell",
  CLAIM: "claim",
  BUYBACK: "buyback",
  OTHER: "other",
} as const;
export type TransactionType = (typeof TransactionType)[keyof typeof TransactionType];

export const TransactionStatus = {
  PENDING: "pending",
  CONFIRMED: "confirmed",
  FAILED: "failed",
  REPLACED: "replaced",
  DROPPED: "dropped",
  REORGED: "reorged",
} as const;
export type TransactionStatus = (typeof TransactionStatus)[keyof typeof TransactionStatus];

export const QuoteSource = {
  CONTRACT_PREVIEW: "contract_preview",
  MOCK: "mock",
  UNAVAILABLE: "unavailable",
} as const;
export type QuoteSource = (typeof QuoteSource)[keyof typeof QuoteSource];

export const EpochStatus = {
  PENDING: "pending",
  SNAPSHOT_COMPLETE: "snapshot_complete",
  PROOF_GENERATED: "proof_generated",
  CLAIM_OPEN: "claim_open",
  CLOSED: "closed",
} as const;
export type EpochStatus = (typeof EpochStatus)[keyof typeof EpochStatus];

export const RpcStatus = {
  OK: "OK",
  DEGRADED: "DEGRADED",
  DOWN: "DOWN",
} as const;
export type RpcStatus = (typeof RpcStatus)[keyof typeof RpcStatus];

export const ContractStatus = {
  ACTIVE: "ACTIVE",
  PAUSED: "PAUSED",
  FINALIZED: "FINALIZED",
  UNKNOWN: "UNKNOWN",
} as const;
export type ContractStatus = (typeof ContractStatus)[keyof typeof ContractStatus];

/** Never show LIVE when data is actually stale/mock */
export function isLive(status: DataStatus): boolean {
  return status === DataStatus.LIVE;
}

export function isMocked(status: DataStatus): boolean {
  return status === DataStatus.MOCK_DATA;
}
