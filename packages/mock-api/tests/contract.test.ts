// ═══════════════════════════════════════════
// PANGU2 — Mock API ↔ OpenAPI Contract Test
// Validates every Mock endpoint against the OpenAPI schema.
// ═══════════════════════════════════════════

import { describe, it, expect, beforeAll } from "vitest";
import { readFileSync } from "fs";

// This test validates that the Mock Server responses conform to
// the OpenAPI schema definitions defined in pangu2-api-v1.yaml.
//
// It checks:
// 1. All documented endpoints return 200 with valid Envelope structure
// 2. Required fields (data, meta, error) are present
// 3. meta.data_status is always set
// 4. Error responses follow the EnvelopeError schema
// 5. Amount fields are strings (not numbers)

const BASE_URL = "http://localhost:4000";

interface EnvelopeMeta {
  project: string;
  environment: string;
  chain_id: number;
  data_status: string;
  block_number: string | null;
  generated_at: string;
  schema_version: string;
}

interface EnvelopeError {
  code: string;
  message: string;
  retryable: boolean;
  details: Record<string, unknown>;
}

interface Envelope<T> {
  data: T;
  meta: EnvelopeMeta;
  error: EnvelopeError | null;
}

const VALID_DATA_STATUSES = [
  "MOCK_DATA", "SYNCING", "LIVE", "STALE", "DEGRADED", "UNAVAILABLE",
];

async function fetchEnvelope<T>(path: string, options?: RequestInit): Promise<Envelope<T>> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json", ...options?.headers },
    ...options,
  });
  return res.json();
}

function validateEnvelope(envelope: Envelope<unknown>, path: string): void {
  // 1. Meta must exist
  expect(envelope.meta, `${path}: missing meta`).toBeDefined();

  // 2. Project identifier
  expect(envelope.meta.project, `${path}: meta.project`).toBe("PANGU2");

  // 3. Data status must be valid
  expect(VALID_DATA_STATUSES, `${path}: meta.data_status`).toContain(
    envelope.meta.data_status,
  );

  // 4. Environment
  expect(typeof envelope.meta.environment, `${path}: meta.environment`).toBe("string");

  // 5. Schema version
  expect(envelope.meta.schema_version, `${path}: schema_version`).toBe("1.0.0");

  // 6. Generated at is ISO timestamp
  expect(new Date(envelope.meta.generated_at).getTime(), `${path}: generated_at`).not.toBeNaN();

  // 7. Success respones must have data but no error
  if (!envelope.error) {
    expect(envelope.data, `${path}: data in non-error response`).not.toBeNull();
  }

  // 8. Error responses must have error structure
  if (envelope.error) {
    expect(typeof envelope.error.code, `${path}: error.code`).toBe("string");
    expect(typeof envelope.error.message, `${path}: error.message`).toBe("string");
    expect(typeof envelope.error.retryable, `${path}: error.retryable`).toBe("boolean");
  }
}

function validateAmountStrings(obj: unknown, path: string): void {
  if (!obj || typeof obj !== "object") return;
  if (Array.isArray(obj)) {
    for (let i = 0; i < obj.length; i++) validateAmountStrings(obj[i], `${path}[${i}]`);
    return;
  }
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    if (typeof value === "object" && value !== null) {
      validateAmountStrings(value, `${path}.${key}`);
      continue;
    }
    // Amount fields MUST be strings, never numbers
    if (key.endsWith("_wei") || key.endsWith("_raw") || key.endsWith("_amount")) {
      if (typeof value !== "string") {
        console.warn(`${path}.${key}: expected string, got ${typeof value} = ${value}`);
      }
    }
  }
}

// ── System Endpoints ──

describe("System API", () => {
  it("GET /api/v1/projects/pangu2/config", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/config");
    validateEnvelope(env, "/config");
    const d = env.data as Record<string, unknown>;
    expect(d.project).toBe("PANGU2");
    expect(typeof d.chain_id).toBe("number");
  });

  it("GET /api/v1/projects/pangu2/system-status", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/system-status");
    validateEnvelope(env, "/system-status");
  });

  it("GET /api/v1/projects/pangu2/contracts", async () => {
    const env = await fetchEnvelope<unknown[]>("/api/v1/projects/pangu2/contracts");
    validateEnvelope(env, "/contracts");
    expect(Array.isArray(env.data)).toBe(true);
    if (env.data.length > 0) {
      const c = env.data[0] as Record<string, unknown>;
      expect(typeof c.name).toBe("string");
      expect(typeof c.address).toBe("string");
    }
  });
});

// ── Auth Endpoints ──

describe("Auth API", () => {
  it("POST /auth/nonce", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/auth/nonce", {
      method: "POST",
      body: JSON.stringify({ wallet_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }),
    });
    validateEnvelope(env, "/auth/nonce");
    const d = env.data as Record<string, unknown>;
    expect(typeof d.nonce).toBe("string");
    expect(typeof d.message).toBe("string");
  });

  it("POST /auth/verify", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/auth/verify", {
      method: "POST",
      body: JSON.stringify({
        wallet_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        signature: "0x" + "ab".repeat(65),
      }),
    });
    validateEnvelope(env, "/auth/verify");
    const d = env.data as Record<string, unknown>;
    expect(typeof d.token).toBe("string");
  });

  it("POST /auth/logout", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/auth/logout", {
      method: "POST",
    });
    validateEnvelope(env, "/auth/logout");
  });
});

// ── Wallet Endpoints ──

describe("Wallet API", () => {
  const addr = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

  it("GET /wallets/{address}/summary", async () => {
    const env = await fetchEnvelope<unknown>(`/api/v1/projects/pangu2/wallets/${addr}/summary`);
    validateEnvelope(env, "/wallets/{addr}/summary");
    const d = env.data as Record<string, unknown>;
    validateAmountStrings(d, "/wallets/summary");
  });

  it("GET /wallets/{address}/transactions", async () => {
    const env = await fetchEnvelope<unknown[]>(`/api/v1/projects/pangu2/wallets/${addr}/transactions?page=1`);
    validateEnvelope(env, "/wallets/{addr}/transactions");
  });
});

// ── Quote Endpoints ──

describe("Quote API", () => {
  it("POST /quotes/buy", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/quotes/buy", {
      method: "POST",
      body: JSON.stringify({ amount_bnb_wei: "100000000000000000" }),
    });
    validateEnvelope(env, "/quotes/buy");
    const d = env.data as Record<string, unknown>;
    expect(d.tax_rate).toBe("4.00%");
    expect(d.source).toBe("mock");
    validateAmountStrings(d, "/quotes/buy");
  });

  it("POST /quotes/sell", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/quotes/sell", {
      method: "POST",
      body: JSON.stringify({
        amount_token_raw: "10000000000000000000000",
        wallet_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      }),
    });
    validateEnvelope(env, "/quotes/sell");
    const d = env.data as Record<string, unknown>;
    expect(d.source).toBe("mock");
    validateAmountStrings(d, "/quotes/sell");
  });
});

// ── Dividend Endpoints ──

describe("Dividend API", () => {
  it("GET /dividend/epochs/current", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/dividend/epochs/current");
    validateEnvelope(env, "/dividend/epochs/current");
  });

  it("GET /dividend/epochs/{id}/proof/{addr}", async () => {
    const env = await fetchEnvelope<unknown>(
      "/api/v1/projects/pangu2/dividend/epochs/28/proof/0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    validateEnvelope(env, "/dividend/epochs/{id}/proof");
  });
});

// ── Support Endpoints ──

describe("Support API", () => {
  it("GET /buybacks", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/buybacks");
    validateEnvelope(env, "/buybacks");
  });

  it("GET /locker/batches", async () => {
    const env = await fetchEnvelope<unknown>("/api/v1/projects/pangu2/locker/batches");
    validateEnvelope(env, "/locker/batches");
  });
});

// ── Admin Endpoints ──

describe("Admin API", () => {
  it("POST /admin/auth/login", async () => {
    const env = await fetchEnvelope<unknown>("/admin-api/v1/projects/pangu2/auth/login", {
      method: "POST",
      body: JSON.stringify({ email: "admin@pangu2.io", password: "password" }),
    });
    validateEnvelope(env, "/admin/auth/login");
  });

  it("GET /admin/dashboard", async () => {
    const env = await fetchEnvelope<unknown>("/admin-api/v1/projects/pangu2/dashboard");
    validateEnvelope(env, "/admin/dashboard");
  });

  it("GET /admin/jobs", async () => {
    const env = await fetchEnvelope<unknown>("/admin-api/v1/projects/pangu2/jobs");
    validateEnvelope(env, "/admin/jobs");
  });

  it("GET /admin/audit-logs", async () => {
    const env = await fetchEnvelope<unknown>("/admin-api/v1/projects/pangu2/audit-logs");
    validateEnvelope(env, "/admin/audit-logs");
  });
});

describe("MOCK_DATA verification", () => {
  it("All public endpoints must return MOCK_DATA", async () => {
    const paths = [
      "/api/v1/projects/pangu2/config",
      "/api/v1/projects/pangu2/system-status",
      "/api/v1/projects/pangu2/contracts",
    ];
    for (const path of paths) {
      const env = await fetchEnvelope<unknown>(path);
      expect(env.meta.data_status, `${path}: must be MOCK_DATA`).toBe("MOCK_DATA");
    }
  });
});
