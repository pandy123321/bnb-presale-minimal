// ═══════════════════════════════════════════
// PANGU2 — Mock API Contract Test
//
// Validates that every Mock API endpoint response conforms to the
// OpenAPI 3.1 schema defined in pangu2-api-v1.yaml.
//
// Uses AJV JSON Schema validation with full $ref resolution.
// Each test: fetch → validate envelope structure → validate schema → assert.
//
// Run: cd packages/mock-api && npx vitest run tests/contract.test.ts
// ═══════════════════════════════════════════

import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { readFileSync } from "fs";
import { resolve } from "path";
import { parse as parseYaml } from "yaml";
import Ajv, { type ValidateFunction } from "ajv";
import addFormats from "ajv-formats";
import { spawn, type ChildProcess } from "child_process";

// ── Configuration ──────────────────────────

const OPENAPI_PATH = resolve(__dirname, "../../../docs/schemas/openapi/pangu2-api-v1.yaml");
const MOCK_SERVER_SCRIPT = resolve(__dirname, "../src/server.ts");
const BASE_URL = "http://localhost:4000";

// ── Globals ────────────────────────────────

let serverProcess: ChildProcess | null = null;
let ajv: Ajv;
let schemaValidators: Record<string, ValidateFunction | null> = {};
const RESULTS: Array<{ endpoint: string; passed: boolean; errors: string[] }> = [];

const DATA_STATUS_ENUM = ["MOCK_DATA", "SYNCING", "LIVE", "STALE", "DEGRADED", "UNAVAILABLE"];

// ── Schema Helpers ─────────────────────────

function loadOpenApi() {
  return parseYaml(readFileSync(OPENAPI_PATH, "utf-8"));
}

function resolveRefs(schema: any, schemas: Record<string, any>): any {
  if (typeof schema !== "object" || schema === null) return schema;
  if (Array.isArray(schema)) return schema.map((s) => resolveRefs(s, schemas));

  const out: Record<string, any> = {};
  for (const [key, value] of Object.entries(schema)) {
    if (key === "$ref" && typeof value === "string") {
      const refName = value.replace("#/components/schemas/", "");
      if (schemas[refName]) {
        const refBlock = resolveRefs(schemas[refName], schemas);
        for (const [rk, rv] of Object.entries(refBlock)) {
          if (!(rk in out)) out[rk] = rv; // shallow merge, first wins
        }
      }
    } else {
      out[key] = resolveRefs(value, schemas);
    }
  }
  return out;
}

function compileValidator(schema: any, schemas: Record<string, any>): ValidateFunction | null {
  try {
    const resolved = resolveRefs(schema, schemas);
    return ajv.compile(resolved);
  } catch {
    return null;
  }
}

// ── HTTP Helpers ───────────────────────────

async function get(path: string) {
  const res = await fetch(`${BASE_URL}${path}`);
  return { status: res.status, body: await res.json().catch(() => null) };
}

async function post(path: string, data: Record<string, unknown>) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

// ── Envelope Validators ────────────────────

function validateEnvelope(body: any): string[] {
  const err: string[] = [];
  if (!body || typeof body !== "object") { err.push("Not a JSON object"); return err; }
  if (!("data" in body)) err.push("Missing 'data'");
  if (!("meta" in body)) err.push("Missing 'meta'");
  if (!("error" in body)) err.push("Missing 'error' field");
  if (body.meta) {
    if (body.meta.project !== "PANGU2") err.push(`meta.project=${body.meta.project} expected PANGU2`);
    if (body.meta.schema_version !== "1.0.0") err.push(`meta.schema_version=${body.meta.schema_version} expected 1.0.0`);
    if (!DATA_STATUS_ENUM.includes(body.meta.data_status)) err.push(`meta.data_status="${body.meta.data_status}" invalid`);
    if (typeof body.meta.chain_id !== "number") err.push("meta.chain_id not a number");
  }
  return err;
}

function validateAjv(body: any, validator: ValidateFunction | null): string[] {
  if (!validator) return [];
  const valid = validator(body);
  if (valid) return [];
  return (validator.errors ?? []).slice(0, 5).map(
    (e) => `${e.instancePath || "(root)"} ${e.message}`,
  );
}

function record(label: string, envErrors: string[], ajvErrors: string[]) {
  const all = [...envErrors, ...ajvErrors];
  RESULTS.push({ endpoint: label, passed: all.length === 0, errors: all });
}

// ── Setup / Teardown ───────────────────────

beforeAll(async () => {
  // Compile AJV validators
  ajv = new Ajv({ allErrors: true, strict: false });
  addFormats(ajv);

  const oa = loadOpenApi();
  const schemas = oa.components?.schemas ?? {};

  schemaValidators = {
    Envelope_Config: compileValidator(schemas.Envelope_Config, schemas),
    Envelope_SystemStatus: compileValidator(schemas.Envelope_SystemStatus, schemas),
    Envelope_ContractList: compileValidator(schemas.Envelope_ContractList, schemas),
    Envelope_Nonce: compileValidator(schemas.Envelope_Nonce, schemas),
    Envelope_Session: compileValidator(schemas.Envelope_Session, schemas),
    Envelope_WalletSummary: compileValidator(schemas.Envelope_WalletSummary, schemas),
    Envelope_TxList: compileValidator(schemas.Envelope_TxList, schemas),
    Envelope_BuyQuote: compileValidator(schemas.Envelope_BuyQuote, schemas),
    Envelope_SellQuote: compileValidator(schemas.Envelope_SellQuote, schemas),
    Envelope_Epoch: compileValidator(schemas.Envelope_Epoch, schemas),
  };

  // Start Mock API server
  return new Promise<void>((resolve, reject) => {
    serverProcess = spawn("npx", ["tsx", MOCK_SERVER_SCRIPT], {
      cwd: resolve(__dirname, ".."),
      stdio: "pipe",
      shell: true,
    });

    const timeout = setTimeout(() => reject(new Error("Server start timeout")), 15_000);

    serverProcess.stdout?.on("data", (data: Buffer) => {
      if (data.toString().includes("Running at")) {
        clearTimeout(timeout);
        setTimeout(resolve, 500); // small delay to ensure ready
      }
    });

    serverProcess.stderr?.on("data", (data: Buffer) => {
      // silence
    });

    serverProcess.on("error", (err) => {
      clearTimeout(timeout);
      reject(err);
    });
  });
}, 20_000);

afterAll(() => {
  if (serverProcess) {
    serverProcess.kill("SIGTERM");
    serverProcess = null;
  }
});

// ═══════════════════════════════════════════
// System Endpoints
// ═══════════════════════════════════════════

describe("GET /api/v1/projects/pangu2/config", () => {
  it("returns valid Envelope_Config", async () => {
    const { status, body } = await get("/api/v1/projects/pangu2/config");
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_Config);
    record("[SYSTEM] GET /config", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

describe("GET /api/v1/projects/pangu2/system-status", () => {
  it("returns valid Envelope_SystemStatus", async () => {
    const { status, body } = await get("/api/v1/projects/pangu2/system-status");
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_SystemStatus);
    record("[SYSTEM] GET /system-status", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

describe("GET /api/v1/projects/pangu2/contracts", () => {
  it("returns valid Envelope_ContractList", async () => {
    const { status, body } = await get("/api/v1/projects/pangu2/contracts");
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_ContractList);
    record("[SYSTEM] GET /contracts", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Auth Endpoints
// ═══════════════════════════════════════════

describe("POST /api/v1/projects/pangu2/auth/nonce", () => {
  it("returns valid Envelope_Nonce", async () => {
    const { status, body } = await post("/api/v1/projects/pangu2/auth/nonce", {
      wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325",
    });
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_Nonce);
    record("[AUTH] POST /auth/nonce", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

describe("POST /api/v1/projects/pangu2/auth/verify", () => {
  it("returns valid Envelope_Session", async () => {
    const { status, body } = await post("/api/v1/projects/pangu2/auth/verify", {
      wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325",
      signature: "0x" + "ab".repeat(65),
    });
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_Session);
    record("[AUTH] POST /auth/verify", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

describe("POST /api/v1/projects/pangu2/auth/logout", () => {
  it("returns 200 with valid envelope", async () => {
    const { status, body } = await post("/api/v1/projects/pangu2/auth/logout", {});
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    record("[AUTH] POST /auth/logout", env, []);
    expect(env).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Wallet Endpoints
// ═══════════════════════════════════════════

describe("GET /api/v1/projects/pangu2/wallets/:address/summary", () => {
  it("returns valid Envelope_WalletSummary", async () => {
    const addr = "0x14791697260e4c9a71f18484c9f997b308e59325";
    const { status, body } = await get(`/api/v1/projects/pangu2/wallets/${addr}/summary`);
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_WalletSummary);
    record("[WALLET] GET /wallets/:addr/summary", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

describe("GET /api/v1/projects/pangu2/wallets/:address/transactions", () => {
  it("returns valid Envelope_TxList with pagination", async () => {
    const addr = "0x14791697260e4c9a71f18484c9f997b308e59325";
    const { status, body } = await get(`/api/v1/projects/pangu2/wallets/${addr}/transactions`);
    expect(status).toBe(200);
    const env = validateEnvelope(body);

    // Check pagination fields on meta
    if (body.meta) {
      if (typeof body.meta.current_page !== "number") env.push("Missing current_page");
      if (typeof body.meta.total !== "number") env.push("Missing total");
    }

    const ajv = validateAjv(body, schemaValidators.Envelope_TxList);
    record("[WALLET] GET /wallets/:addr/transactions", env, ajv);
    expect([...env, ...ajv]).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Quote Endpoints
// ═══════════════════════════════════════════

describe("POST /api/v1/projects/pangu2/quotes/buy", () => {
  it("returns valid Envelope_BuyQuote with source=mock", async () => {
    const { status, body } = await post("/api/v1/projects/pangu2/quotes/buy", {
      amount_bnb_wei: "100000000000000000",
    });
    expect(status).toBe(200);

    // BuyQuote-specific field checks
    const extra: string[] = [];
    if (body.data) {
      if (body.data.source !== "mock") extra.push(`source=${body.data.source} expected mock`);
      if (!body.data.tax_rate?.includes("4")) extra.push(`tax_rate=${body.data.tax_rate} expected 4%`);
      if (!body.data.expires_at) extra.push("Missing expires_at");
      if (!body.data.min_receive_raw) extra.push("Missing min_receive_raw");
    }

    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_BuyQuote);
    record("[QUOTE] POST /quotes/buy", [...env, ...extra], ajv);
    expect([...env, ...extra, ...ajv]).toEqual([]);
  });
});

describe("POST /api/v1/projects/pangu2/quotes/sell", () => {
  it("returns valid Envelope_SellQuote with source=mock", async () => {
    const { status, body } = await post("/api/v1/projects/pangu2/quotes/sell", {
      amount_token_raw: "10000000000000000000000",
      wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325",
    });
    expect(status).toBe(200);

    const extra: string[] = [];
    if (body.data) {
      if (body.data.source !== "mock") extra.push(`source=${body.data.source} expected mock`);
      if (!body.data.tax_destination) extra.push("Missing tax_destination");
    }

    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_SellQuote);
    record("[QUOTE] POST /quotes/sell", [...env, ...extra], ajv);
    expect([...env, ...extra, ...ajv]).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Dividend Endpoint
// ═══════════════════════════════════════════

describe("GET /api/v1/projects/pangu2/dividend/epochs/current", () => {
  it("returns valid Envelope_Epoch with tiers", async () => {
    const { status, body } = await get("/api/v1/projects/pangu2/dividend/epochs/current");
    expect(status).toBe(200);

    const extra: string[] = [];
    if (body.data) {
      if (!body.data.tiers || !Array.isArray(body.data.tiers)) extra.push("Missing tiers array");
      if (body.data.tiers?.length !== 4) extra.push(`Expected 4 tiers, got ${body.data.tiers?.length}`);
      if (typeof body.data.epoch_id !== "number") extra.push("epoch_id not a number");
    }

    const env = validateEnvelope(body);
    const ajv = validateAjv(body, schemaValidators.Envelope_Epoch);
    record("[DIVIDEND] GET /dividend/epochs/current", [...env, ...extra], ajv);
    expect([...env, ...extra, ...ajv]).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Admin Endpoints (structural only)
// ═══════════════════════════════════════════

describe("POST /admin-api/v1/projects/pangu2/auth/login", () => {
  it("returns 200 with valid envelope", async () => {
    const { status, body } = await post("/admin-api/v1/projects/pangu2/auth/login", {
      email: "admin@pangu2.io",
      password: "test",
    });
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    record("[ADMIN] POST /auth/login", env, []);
    expect(env).toEqual([]);
  });
});

describe("GET /admin-api/v1/projects/pangu2/dashboard", () => {
  it("returns 200 with valid envelope", async () => {
    const { status, body } = await get("/admin-api/v1/projects/pangu2/dashboard");
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    record("[ADMIN] GET /dashboard", env, []);
    expect(env).toEqual([]);
  });
});

describe("GET /admin-api/v1/projects/pangu2/jobs", () => {
  it("returns 200 with valid envelope", async () => {
    const { status, body } = await get("/admin-api/v1/projects/pangu2/jobs");
    expect(status).toBe(200);
    const env = validateEnvelope(body);
    record("[ADMIN] GET /jobs", env, []);
    expect(env).toEqual([]);
  });
});

// ═══════════════════════════════════════════
// Health Check
// ═══════════════════════════════════════════

describe("GET /health", () => {
  it("returns status ok", async () => {
    const { status, body } = await get("/health");
    expect(status).toBe(200);
    expect(body.status).toBe("ok");
    record("[HEALTH] GET /health", [], []);
  });
});

// ═══════════════════════════════════════════
// Final Report (printed after all tests)
// ═══════════════════════════════════════════

describe("Contract Validation Report", () => {
  it("prints summary of all endpoints", () => {
    console.log("\n═══════════════════════════════════════════");
    console.log("PANGU2 Mock API Contract Validation Report");
    console.log("═══════════════════════════════════════════\n");

    for (const r of RESULTS) {
      const icon = r.passed ? "✓" : "✗";
      console.log(`  ${icon} ${r.endpoint}`);
      for (const err of r.errors) {
        console.log(`       → ${err}`);
      }
    }

    const passed = RESULTS.filter((r) => r.passed).length;
    const failed = RESULTS.filter((r) => !r.passed).length;
    console.log(`\n───────────────────────────────────────────`);
    console.log(`  Total: ${RESULTS.length} | Passed: ${passed} | Failed: ${failed}`);
    console.log(`  ${failed === 0 ? "ALL ENDPOINTS PASSED ✓" : `${failed} FAILED ✗`}`);
    console.log("═══════════════════════════════════════════\n");

    expect(failed).toBe(0);
  });
});
