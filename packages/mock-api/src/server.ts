// ═══════════════════════════════════════════
// PANGU2 — Mock API Server
// All responses explicitly marked MOCK_DATA
// ═══════════════════════════════════════════
import express from "express";
import cors from "cors";

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 4000;
const MOCK_BLOCK = "42815128";

function envelope<T>(data: T) {
  return {
    data,
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "MOCK_DATA",
      block_number: MOCK_BLOCK,
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
    },
    error: null,
  };
}

function errorEnvelope(code: string, message: string, retryable = true) {
  return {
    data: null,
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "MOCK_DATA",
      block_number: null,
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
    },
    error: { code, message, retryable, details: {} },
  };
}

// ── System ──
app.get("/api/v1/projects/pangu2/config", (_req, res) => {
  res.json(envelope({
    project: "PANGU2",
    environment: "LOCAL",
    chain_id: 31337,
    chain_name: "Anvil",
    rpc_status: "OK",
    supported_networks: [31337, 97],
  }));
});

app.get("/api/v1/projects/pangu2/system-status", (_req, res) => {
  res.json(envelope({
    latest_chain_block: MOCK_BLOCK,
    last_scanned_block: "42815125",
    block_lag: 3,
    rpc_status: "OK",
    queue_status: "HEALTHY",
    open_anomalies: 0,
  }));
});

app.get("/api/v1/projects/pangu2/contracts", (_req, res) => {
  res.json(envelope([
    { name: "BNBPresale", address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", abi_version: "1.0.0", deployment_block: "42000000", status: "ACTIVE" },
    { name: "Distributor", address: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", abi_version: "1.0.0", deployment_block: "42000001", status: "ACTIVE" },
    { name: "BuybackLocker", address: "0xcccccccccccccccccccccccccccccccccccccccc", abi_version: "1.0.0", deployment_block: "42000002", status: "ACTIVE" },
    { name: "Timelock", address: "0xdddddddddddddddddddddddddddddddddddddddd", abi_version: "1.0.0", deployment_block: "42000003", status: "ACTIVE" },
    { name: "SafeMultisig", address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", abi_version: "1.0.0", deployment_block: "42000004", status: "ACTIVE" },
  ]));
});

// ── Auth ──
app.post("/api/v1/projects/pangu2/auth/nonce", (req, res) => {
  const { wallet_address } = req.body;
  const nonce = `pangu2-auth-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  res.json(envelope({
    nonce,
    message: `PANGU2 auth nonce: ${nonce}\nWallet: ${wallet_address}\nChain: 31337`,
    expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
  }));
});

app.post("/api/v1/projects/pangu2/auth/verify", (req, res) => {
  const { wallet_address } = req.body;
  res.json(envelope({
    token: `p2-session-${Date.now()}`,
    wallet_address,
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
  }));
});

app.post("/api/v1/projects/pangu2/auth/logout", (_req, res) => {
  res.json(envelope({ ok: true }));
});

// ── Wallet ──
app.get("/api/v1/projects/pangu2/wallets/:address/summary", (req, res) => {
  res.json(envelope({
    address: req.params.address,
    balance_token_raw: "126840000000000000000000",
    balance_token_formatted: "126,840",
    cost_basis: "100.00 USDT",
    current_sell_tax_rate: "4%",
    rank: 36,
    claimable_amount_raw: "2846000000000000000000",
  }));
});

app.get("/api/v1/projects/pangu2/wallets/:address/transactions", (_req, res) => {
  res.json({
    data: [
      { tx_hash: "0x1111111111111111111111111111111111111111111111111111111111111111", block_number: MOCK_BLOCK, type: "buy", amount_in: "0.10 BNB", amount_out: "44,385.6 P2", status: "confirmed", timestamp: "2026-08-01T12:00:00Z" },
      { tx_hash: "0x2222222222222222222222222222222222222222222222222222222222222222", block_number: "42815100", type: "claim", amount_in: "—", amount_out: "2,846 P2", status: "confirmed", timestamp: "2026-08-01T11:00:00Z" },
    ],
    meta: {
      project: "PANGU2",
      environment: "LOCAL",
      chain_id: 31337,
      data_status: "MOCK_DATA",
      block_number: MOCK_BLOCK,
      generated_at: new Date().toISOString(),
      schema_version: "1.0.0",
      current_page: 1,
      per_page: 20,
      total: 2,
      last_page: 1,
    },
    error: null,
  });
});

// ── Quote ──
app.post("/api/v1/projects/pangu2/quotes/buy", (req, res) => {
  const { amount_bnb_wei } = req.body || {};
  const amount = BigInt(amount_bnb_wei ?? "100000000000000000");
  const rate = 462350n;
  const gross = (amount * rate) / 10n ** 18n;
  const tax = (gross * 4n) / 100n;
  const net = gross - tax;
  res.json(envelope({
    amount_in_wei: amount.toString(),
    gross_tokens_raw: gross.toString(),
    tax_rate: "4.00%",
    tax_tokens_raw: tax.toString(),
    net_tokens_raw: net.toString(),
    min_receive_raw: ((net * 99n) / 100n).toString(),
    quote_block: MOCK_BLOCK,
    expires_at: new Date(Date.now() + 30_000).toISOString(),
    source: "mock",
  }));
});

app.post("/api/v1/projects/pangu2/quotes/sell", (_req, res) => {
  res.json(envelope({
    amount_in_raw: "10000000000000000000000",
    gross_bnb_wei: "21630000000000",
    tax_rate: "4.00%",
    tax_tokens_raw: "400000000000000000000",
    tax_destination: "4% enters SupportPool",
    net_bnb_wei: "21400000000000",
    min_receive_wei: "21100000000000",
    quote_block: MOCK_BLOCK,
    expires_at: new Date(Date.now() + 30_000).toISOString(),
    source: "mock",
  }));
});

// ── Dividend ──
app.get("/api/v1/projects/pangu2/dividend/epochs/current", (_req, res) => {
  res.json(envelope({
    epoch_id: 28,
    snapshot_block: "42814660",
    total_dividend_raw: "6420000000000000000000000",
    merkle_root: "0x76b100000000000000000000000000000000000000000000000000000000c4a8",
    tiers: [
      { name: "Tier 1", rank_range: "1-10", share_percent: 35 },
      { name: "Tier 2", rank_range: "11-30", share_percent: 25 },
      { name: "Tier 3", rank_range: "31-60", share_percent: 25 },
      { name: "Tier 4", rank_range: "61-100", share_percent: 15 },
    ],
    status: "claim_open",
  }));
});

app.get("/api/v1/projects/pangu2/dividend/epochs/:epochId", (req, res) => {
  res.json(envelope({
    epoch_id: parseInt(req.params.epochId),
    snapshot_block: "42814660",
    total_dividend_raw: "6420000000000000000000000",
    merkle_root: "0x76b100000000000000000000000000000000000000000000000000000000c4a8",
    tiers: [],
    status: "claim_open",
  }));
});

app.get("/api/v1/projects/pangu2/dividend/epochs/:epochId/proof/:address", (_req, res) => {
  res.json(envelope({
    epoch_id: 28,
    address: _req.params.address,
    amount_raw: "2846000000000000000000",
    proof: ["0xaaaa...", "0xbbbb...", "0xcccc..."],
    claimed: false,
  }));
});

// ── Support ──
app.get("/api/v1/projects/pangu2/buybacks", (_req, res) => {
  res.json({
    data: [
      { batch_id: 1247, amount_bnb_wei: "10000000000000000", tokens_raw: "4612000000000000000000", timestamp: new Date(Date.now() - 120_000).toISOString() },
      { batch_id: 1246, amount_bnb_wei: "10000000000000000", tokens_raw: "4598000000000000000000", timestamp: new Date(Date.now() - 180_000).toISOString() },
    ],
    meta: { ...envelope([]).meta, current_page: 1, per_page: 20, total: 2, last_page: 1 },
    error: null,
  });
});

app.get("/api/v1/projects/pangu2/locker/batches", (_req, res) => {
  res.json({
    data: [
      { batch_id: 1247, tokens_raw: "4612000000000000000000", locked_until: new Date(Date.now() + 365 * 24 * 3600 * 1000).toISOString() },
    ],
    meta: { ...envelope([]).meta, current_page: 1, per_page: 20, total: 1, last_page: 1 },
    error: null,
  });
});

// ── Admin ──
const MOCK_ADMIN = {
  id: 1,
  name: "Super Admin",
  email: "admin@pangu2.io",
  role: "SUPER_ADMIN" as const,
};
const MOCK_ADMIN_PASSWORD = "password";

app.post("/admin-api/v1/projects/pangu2/auth/login", (req, res) => {
  const email = typeof req.body?.email === "string" ? req.body.email.trim().toLowerCase() : "";
  const password = typeof req.body?.password === "string" ? req.body.password : "";

  if (!email || !password) {
    res.status(422).json(errorEnvelope("VALIDATION_ERROR", "Email and password are required.", false));
    return;
  }

  if (email !== MOCK_ADMIN.email || password !== MOCK_ADMIN_PASSWORD) {
    res.status(401).json(errorEnvelope("AUTH_FAILED", "Invalid credentials.", false));
    return;
  }

  res.json(envelope({
    token: "admin-session-token",
    admin: MOCK_ADMIN,
  }));
});

// Required by Admin router guard (checkSession) after refresh / navigation
app.get("/admin-api/v1/projects/pangu2/auth/me", (req, res) => {
  const auth = req.headers.authorization ?? "";
  if (!auth.startsWith("Bearer ")) {
    res.status(401).json({ data: null, meta: envelope(null).meta, error: { code: "UNAUTHORIZED", message: "Missing bearer token" } });
    return;
  }
  res.json(envelope(MOCK_ADMIN));
});

app.get("/admin-api/v1/projects/pangu2/dashboard", (_req, res) => {
  res.json(envelope({
    total_bnb_raised_wei: "128400000000000000000",
    total_tokens_sold_raw: "59300000000000000000000000",
    unique_wallets: 1284,
    active_epoch: 28,
    support_pool_bnb: "18420000000000000000",
    buyback_executed: 1247,
    open_anomalies: 0,
  }));
});

app.get("/admin-api/v1/projects/pangu2/contracts", (_req, res) => {
  res.json(envelope([
    { name: "BNBPresale", address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", abi_version: "1.0.0", deployment_block: "42000000", status: "ACTIVE" },
    { name: "Distributor", address: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", abi_version: "1.0.0", deployment_block: "42000001", status: "ACTIVE" },
    { name: "BuybackLocker", address: "0xcccccccccccccccccccccccccccccccccccccccc", abi_version: "1.0.0", deployment_block: "42000002", status: "ACTIVE" },
  ]));
});

app.get("/admin-api/v1/projects/pangu2/jobs", (_req, res) => {
  res.json(envelope([
    { name: "chain-sync", status: "RUNNING", run_id: "run-chain-sync-001", last_error: null, processed: 1284, errors: 0, last_run: new Date().toISOString() },
    { name: "dividend-snapshot", status: "IDLE", run_id: "run-dividend-001", last_error: null, processed: 28, errors: 0, last_run: "2026-08-01T00:00:00Z" },
    { name: "buyback-watcher", status: "RUNNING", run_id: "run-buyback-001", last_error: null, processed: 1247, errors: 0, last_run: new Date().toISOString() },
  ]));
});

app.get("/admin-api/v1/projects/pangu2/audit-logs", (_req, res) => {
  res.json({
    data: [
      {
        id: 1,
        action: "JOB_RETRY_QUEUED",
        target_type: "job:chain-sync",
        admin_email: "admin@pangu2.io",
        admin_role: "SUPER_ADMIN",
        ip_address: "127.0.0.1",
        result: "SUCCESS",
        created_at: new Date().toISOString(),
      },
    ],
    meta: { ...envelope([]).meta, current_page: 1, per_page: 20, total: 1, last_page: 1 },
    error: null,
  });
});

// ── Health ──
app.get("/health", (_req, res) => {
  res.json({ status: "ok", mock: true });
});

app.listen(PORT, () => {
  console.log(`[PANGU2 Mock API] Running at http://localhost:${PORT}`);
  console.log(`[PANGU2 Mock API] ALL responses are MOCK_DATA — never represent real chain state`);
});
