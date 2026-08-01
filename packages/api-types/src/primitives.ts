// ═══════════════════════════════════════════
// PANGU2 — Shared Primitive Types
// Source: docs/schemas/openapi/pangu2-api-v1.yaml
// DO NOT EDIT MANUALLY — regenerated from OpenAPI
// ═══════════════════════════════════════════

/** Normalized lowercase EVM address (0x + 40 hex chars) */
export type EvmAddress = string & { readonly __brand: "EvmAddress" };

/** Transaction hash (0x + 64 hex chars) */
export type TxHash = string & { readonly __brand: "TxHash" };

/** Decimal integer string (wei or smallest token unit) */
export type WeiAmount = string & { readonly __brand: "WeiAmount" };

/** Decimal integer string for block numbers (avoids JS precision loss) */
export type BlockNumberStr = string & { readonly __brand: "BlockNumber" };

/** RFC 3339 UTC timestamp */
export type IsoTimestamp = string & { readonly __brand: "IsoTimestamp" };
