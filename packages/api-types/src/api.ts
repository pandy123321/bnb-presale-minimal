// ═══════════════════════════════════════════
// PANGU2 — API Request/Response Types
// Source: docs/schemas/openapi/pangu2-api-v1.yaml
// ═══════════════════════════════════════════

import type { EvmAddress, TxHash, WeiAmount, BlockNumberStr, IsoTimestamp } from "./primitives";
import type { DataStatus, RpcStatus, ContractStatus, TransactionType, TransactionStatus, QuoteSource, EpochStatus } from "./enums";

// ── Universal Envelope ──

export interface EnvelopeMeta {
  project: string;
  environment: string;
  chain_id: number;
  data_status: DataStatus;
  block_number: BlockNumberStr | null;
  generated_at: IsoTimestamp;
  schema_version: string;
}

export interface EnvelopeError {
  code: string;
  message: string;
  retryable: boolean;
  details: Record<string, unknown>;
}

export interface Envelope<T, M = EnvelopeMeta> {
  data: T;
  meta: M;
  error: EnvelopeError | null;
}

export interface PaginationMeta {
  current_page: number;
  per_page: number;
  total: number;
  last_page: number;
}

// ── System / Config ──

export interface EnvironmentConfig {
  project: string;
  environment: string;
  chain_id: number;
  chain_name: string;
  rpc_status: RpcStatus;
  supported_networks: number[];
}

export interface SystemStatus {
  latest_chain_block: BlockNumberStr;
  last_scanned_block: BlockNumberStr;
  block_lag: number;
  rpc_status: RpcStatus;
  queue_status: string;
  open_anomalies: number;
}

export interface ContractInfo {
  name: string;
  address: EvmAddress;
  abi_version: string;
  deployment_block: BlockNumberStr;
  status: ContractStatus;
}

// ── Auth ──

export interface NonceRequest {
  wallet_address: EvmAddress;
}

export interface NonceResponse {
  nonce: string;
  message: string;
  expires_at: IsoTimestamp;
}

export interface VerifyRequest {
  wallet_address: EvmAddress;
  signature: string;
}

export interface SessionInfo {
  token: string;
  wallet_address: EvmAddress;
  expires_at: IsoTimestamp;
}

// ── Wallet ──

export interface WalletSummary {
  address: EvmAddress;
  balance_token_raw: WeiAmount;
  balance_token_formatted: string;
  cost_basis: string;
  current_sell_tax_rate: string;
  rank: number | null;
  claimable_amount_raw: WeiAmount | null;
}

export interface TransactionInfo {
  tx_hash: TxHash;
  block_number: BlockNumberStr;
  type: TransactionType;
  amount_in: string;
  amount_out: string;
  status: TransactionStatus;
  timestamp: IsoTimestamp;
}

// ── Quote ──

export interface BuyQuoteRequest {
  amount_bnb_wei: WeiAmount;
}

export interface BuyQuote {
  amount_in_wei: WeiAmount;
  gross_tokens_raw: WeiAmount;
  tax_rate: string;
  tax_tokens_raw: WeiAmount;
  net_tokens_raw: WeiAmount;
  min_receive_raw: WeiAmount;
  quote_block: BlockNumberStr;
  expires_at: IsoTimestamp;
  source: QuoteSource;
}

export interface SellQuoteRequest {
  amount_token_raw: WeiAmount;
  wallet_address: EvmAddress;
}

export interface SellQuote {
  amount_in_raw: WeiAmount;
  gross_bnb_wei: WeiAmount;
  tax_rate: string;
  tax_tokens_raw: WeiAmount;
  tax_destination: string;
  net_bnb_wei: WeiAmount;
  min_receive_wei: WeiAmount;
  quote_block: BlockNumberStr;
  expires_at: IsoTimestamp;
  source: QuoteSource;
}

// ── Dividend ──

export interface DividendTier {
  name: string;
  rank_range: string;
  share_percent: number;
}

export interface EpochInfo {
  epoch_id: number;
  snapshot_block: BlockNumberStr;
  total_dividend_raw: WeiAmount;
  merkle_root: string;
  tiers: DividendTier[];
  status: EpochStatus;
}

// ── Buyback & Locker ──

/** Buyback event as returned by GET /api/v1/projects/pangu2/buybacks */
export interface BuybackEventDto {
  batch_id: string;
  amount_bnb_wei: string;
  tokens_raw: string;
  trigger: string;
  locker: string;
  timestamp: IsoTimestamp;
}

/** Locker batch as returned by GET /api/v1/projects/pangu2/locker/batches */
export interface LockerBatchDto {
  batch_id: string;
  tokens_raw: string;
  locked_until: IsoTimestamp | null;
  duration_days: number;
  status: string;
}

// ── Admin ──

export interface AdminLoginRequest {
  email: string;
  password: string;
}
