// PANGU2 Chain Worker — Config
// Single source of truth for all runtime configuration.
// Both event-scanner and reorg-detector read from this module.

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) { console.error(`[Config] FATAL: ${key} is required`); process.exit(1); }
  return v;
}

function parseIntSafe(raw: string | undefined, name: string, min: number, max: number): number {
  if (!raw) { console.error(`[Config] FATAL: ${name} is required`); process.exit(1); }
  const n = Number(raw);
  if (!Number.isSafeInteger(n) || n < min || n > max) {
    console.error(`[Config] FATAL: ${name}=${raw} — must be integer ${min}-${max}`);
    process.exit(1);
  }
  return n;
}

// Accept old env var names with deprecation warning
function env(key: string, legacy?: string): string {
  if (process.env[key]) return process.env[key]!;
  if (legacy && process.env[legacy]) {
    console.warn(`[Config] DEPRECATED: ${legacy} is replaced by ${key}`);
    return process.env[legacy]!;
  }
  return "";
}

export const CHAIN_ID          = parseIntSafe(env("CHAIN_ID"), "CHAIN_ID", 1, 999999);
export const RPC_URL           = env("CHAIN_WORKER_RPC_URL", "RPC_URL") || "http://localhost:8545";
export const SCAN_BATCH_SIZE   = parseIntSafe(env("SCAN_BATCH_SIZE", "SCAN_BATCH_SIZE"), "SCAN_BATCH_SIZE", 1, 100000);
export const CONFIRMATION_BLOCKS = parseIntSafe(env("CONFIRMATION_BLOCKS", "CONFIRMATION_BLOCKS"), "CONFIRMATION_BLOCKS", 0, 1000);
export const REORG_DEPTH       = parseIntSafe(env("REORG_DEPTH", "REORG_DEPTH"), "REORG_DEPTH", 1, 10000);
export const SCAN_INTERVAL_SECONDS = parseIntSafe(env("SCAN_INTERVAL_SECONDS", "SCAN_INTERVAL_SECONDS"), "SCAN_INTERVAL_SECONDS", 1, 3600);
export const WORKER_ID         = process.env.WORKER_ID || "worker-default";
export const LEASE_TTL_SECONDS = parseIntSafe(env("LEASE_TTL_SECONDS", "LEASE_TTL_SECONDS"), "LEASE_TTL_SECONDS", 5, 3600);
export const DEPLOYMENT_BLOCK  = parseIntSafe(env("DEPLOYMENT_BLOCK", "DEPLOYMENT_BLOCK"), "DEPLOYMENT_BLOCK", 0, 999999999);

export const TRADE_ROUTER_ADDRESS = requireEnv("CHAIN_WORKER_TRADE_ROUTER_ADDRESS").toLowerCase();
export const DIVIDEND_DISTRIBUTOR_ADDRESS = requireEnv("CHAIN_WORKER_DIVIDEND_ADDRESS").toLowerCase();

/** Sanitised RPC URL for logging — only host:port, no credentials/path */
export function rpcLogLabel(): string {
  try {
    const u = new URL(RPC_URL);
    return `${u.protocol}//${u.hostname}${u.port ? `:${u.port}` : ""}`;
  } catch { return "invalid-url"; }
}
