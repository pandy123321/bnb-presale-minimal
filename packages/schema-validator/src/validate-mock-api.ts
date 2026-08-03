#!/usr/bin/env tsx
// ═══════════════════════════════════════════
// PANGU2 — Mock Response ↔ OpenAPI Schema Validator
//
// Validates that the Mock API Server's responses conform to the OpenAPI 3.1 schema.
// Run: npx tsx src/validate-mock-api.ts
//
// This is a Node.js script that:
// 1. Parses the OpenAPI YAML schema
// 2. Compiles it into JSON Schema for each endpoint response
// 3. Spawns the Mock API server
// 4. Calls each endpoint
// 5. Validates the response against the schema
// 6. Reports PASS/FAIL for each endpoint
//
// Dependencies: npm install ajv ajv-formats yaml
// ═══════════════════════════════════════════

import { readFileSync } from "fs";
import { resolve } from "path";
import { parse as parseYaml } from "yaml";
import Ajv, { type ValidateFunction } from "ajv";
import addFormats from "ajv-formats";
import { execSync, spawn, type ChildProcess } from "child_process";

// ── Configuration ──────────────────────────

const OPENAPI_PATH = resolve(__dirname, "../../../docs/schemas/openapi/pangu2-api-v1.yaml");
const MOCK_API_DIR = resolve(__dirname, "../../mock-api");
const MOCK_BASE_URL = "http://localhost:4000/api/v1/projects/pangu2";
const ADMIN_BASE_URL = "http://localhost:4000/admin-api/v1/projects/pangu2";

// ── Types ──────────────────────────────────

interface ValidationResult {
  endpoint: string;
  method: string;
  path: string;
  passed: boolean;
  errors: string[];
  responseSnippet: string;
}

// ── Schema Loading ──────────────────────────

function loadOpenApiYaml(): Record<string, any> {
  const yamlContent = readFileSync(OPENAPI_PATH, "utf-8");
  return parseYaml(yamlContent);
}

/**
 * Build a JSON Schema that matches the OpenAPI response envelope.
 * The envelope is: { data: <T>, meta: EnvelopeMeta, error: null }
 * We need to validate the full response body.
 */
function buildEnvelopeSchema(
  openapiDoc: Record<string, any>,
  envelopeName: string,
): Record<string, any> | null {
  const schemas = openapiDoc.components?.schemas;
  if (!schemas) return null;

  const envelopeSchema = schemas[envelopeName];
  if (!envelopeSchema) return null;

  // Deep-clone and resolve $ref to EnvelopeMeta
  return resolveRefs(envelopeSchema, schemas);
}

function resolveRefs(schema: any, schemas: Record<string, any>): any {
  if (typeof schema !== "object" || schema === null) return schema;
  if (Array.isArray(schema)) return schema.map(s => resolveRefs(s, schemas));

  const resolved: Record<string, any> = {};
  for (const [key, value] of Object.entries(schema)) {
    if (key === "$ref" && typeof value === "string") {
      const refName = value.replace("#/components/schemas/", "");
      if (schemas[refName]) {
        const refResolved = resolveRefs(schemas[refName], schemas);
        Object.assign(resolved, refResolved);
      }
    } else {
      resolved[key] = resolveRefs(value, schemas);
    }
  }
  return resolved;
}

// ── AJV Validator ───────────────────────────

function createValidator(): Ajv {
  const ajv = new Ajv({ allErrors: true, strict: false });
  addFormats(ajv);
  return ajv;
}

function formatAjvErrors(errors: any[] | null | undefined): string[] {
  if (!errors || errors.length === 0) return [];
  return errors.slice(0, 5).map((e: any) => {
    return `${e.instancePath || "(root)"} ${e.message}${e.params ? ` (${JSON.stringify(e.params)})` : ""}`;
  });
}

// ── HTTP Helpers ────────────────────────────

async function httpGet(url: string): Promise<{ status: number; body: any }> {
  const res = await fetch(url);
  const body = await res.json();
  return { status: res.status, body };
}

async function httpPost(url: string, data: Record<string, unknown>): Promise<{ status: number; body: any }> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  const body = await res.json();
  return { status: res.status, body };
}

// ── Main Validation ─────────────────────────

const ENDPOINTS: Array<{
  label: string;
  method: "GET" | "POST";
  url: string;
  postBody?: Record<string, unknown>;
  envelopeSchema?: string;
}> = [
  { label: "GET /config",        method: "GET",  url: `${MOCK_BASE_URL}/config` },
  { label: "GET /system-status", method: "GET",  url: `${MOCK_BASE_URL}/system-status` },
  { label: "GET /contracts",     method: "GET",  url: `${MOCK_BASE_URL}/contracts` },
  { label: "POST /auth/nonce",   method: "POST", url: `${MOCK_BASE_URL}/auth/nonce`,   postBody: { wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325" } },
  { label: "POST /auth/verify",  method: "POST", url: `${MOCK_BASE_URL}/auth/verify`,  postBody: { wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325", signature: "0x" + "ab".repeat(65) } },
  { label: "POST /auth/logout",  method: "POST", url: `${MOCK_BASE_URL}/auth/logout` },
  { label: "GET /wallets/:addr/summary",     method: "GET", url: `${MOCK_BASE_URL}/wallets/0x14791697260e4c9a71f18484c9f997b308e59325/summary` },
  { label: "GET /wallets/:addr/transactions", method: "GET", url: `${MOCK_BASE_URL}/wallets/0x14791697260e4c9a71f18484c9f997b308e59325/transactions` },
  { label: "POST /quotes/buy",  method: "POST", url: `${MOCK_BASE_URL}/quotes/buy`,  postBody: { amount_bnb_wei: "100000000000000000" } },
  { label: "POST /quotes/sell", method: "POST", url: `${MOCK_BASE_URL}/quotes/sell`, postBody: { amount_token_raw: "10000000000000000000000", wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325" } },
  { label: "GET /dividend/epochs/current", method: "GET", url: `${MOCK_BASE_URL}/dividend/epochs/current` },
  { label: "GET /buybacks",     method: "GET", url: `${MOCK_BASE_URL}/buybacks` },
  { label: "GET /locker/batches", method: "GET", url: `${MOCK_BASE_URL}/locker/batches` },
  { label: "POST /admin/auth/login",   method: "POST", url: `${ADMIN_BASE_URL}/auth/login`, postBody: { email: "admin@pangu2.io", password: "password" } },
  { label: "GET /admin/dashboard",     method: "GET", url: `${ADMIN_BASE_URL}/dashboard` },
  { label: "GET /admin/contracts",     method: "GET", url: `${ADMIN_BASE_URL}/contracts` },
  { label: "GET /admin/jobs",          method: "GET", url: `${ADMIN_BASE_URL}/jobs` },
  { label: "GET /admin/audit-logs",    method: "GET", url: `${ADMIN_BASE_URL}/audit-logs` },
  { label: "GET /health",              method: "GET", url: "http://localhost:4000/health" },
];

// ── Envelope Structural Validation ──────────

function validateEnvelopeStructure(body: any): string[] {
  const errors: string[] = [];

  // Top-level structure
  if (!body || typeof body !== "object") {
    errors.push("Response is not a JSON object");
    return errors;
  }

  if (!("data" in body)) errors.push('Missing top-level "data" field');
  if (!("meta" in body)) errors.push('Missing top-level "meta" field');
  if (!("error" in body)) errors.push('Missing top-level "error" field');

  // Meta fields
  const meta = body.meta;
  if (meta) {
    if (typeof meta.project !== "string" || meta.project !== "PANGU2") {
      errors.push(`meta.project expected "PANGU2", got "${meta.project}"`);
    }
    if (typeof meta.schema_version !== "string" || meta.schema_version !== "1.0.0") {
      errors.push(`meta.schema_version expected "1.0.0", got "${meta.schema_version}"`);
    }
    if (typeof meta.chain_id !== "number") {
      errors.push(`meta.chain_id expected number, got ${typeof meta.chain_id}`);
    }
    const validStatuses = ["MOCK_DATA", "SYNCING", "LIVE", "STALE", "DEGRADED", "UNAVAILABLE"];
    if (!validStatuses.includes(meta.data_status)) {
      errors.push(`meta.data_status "${meta.data_status}" not in valid enum [${validStatuses.join(", ")}]`);
    }
    if (meta.generated_at && typeof meta.generated_at !== "string") {
      errors.push("meta.generated_at must be a string (ISO timestamp)");
    }
  }

  return errors;
}

// ── Detailed Field Validation ──────────────

function validateFieldTypes(body: any, path: string): string[] {
  const errors: string[] = [];
  const meta = body.meta;

  if (path.includes("/wallets/") && path.includes("/transactions")) {
    // Paginated envelope: meta should include pagination fields
    if (meta) {
      if (typeof meta.current_page !== "number") errors.push("meta.current_page missing for paginated response");
      if (typeof meta.per_page !== "number") errors.push("meta.per_page missing for paginated response");
      if (typeof meta.total !== "number") errors.push("meta.total missing for paginated response");
    }
  }
  return errors;
}

// ── Run ────────────────────────────────────

async function main() {
  console.log("═══════════════════════════════════════════");
  console.log("PANGU2 Mock API ↔ OpenAPI Schema Validator");
  console.log("═══════════════════════════════════════════\n");

  // Load schema
  console.log(`[1/4] Loading OpenAPI schema from ${OPENAPI_PATH}...`);
  const openapiDoc = loadOpenApiYaml();
  console.log(`  Schema version: ${openapiDoc.info.version}`);
  console.log(`  Endpoints defined: ${Object.keys(openapiDoc.paths).length}\n`);

  // Compile JSON Schema validators
  console.log("[2/4] Compiling JSON Schema validators...");
  const ajv = createValidator();
  const envelopeSchemas: Record<string, ValidateFunction | null> = {};
  const schemaNames = [
    "Envelope_Config", "Envelope_SystemStatus", "Envelope_ContractList",
    "Envelope_Nonce", "Envelope_Session", "Envelope_WalletSummary",
    "Envelope_TxList", "Envelope_BuyQuote", "Envelope_SellQuote",
    "Envelope_Epoch",
  ];
  for (const name of schemaNames) {
    const schema = buildEnvelopeSchema(openapiDoc, name);
    if (schema) {
      envelopeSchemas[name] = ajv.compile(schema);
    } else {
      envelopeSchemas[name] = null;
    }
  }
  console.log(`  Compiled ${schemaNames.filter(n => envelopeSchemas[n]).length} validators\n`);

  // Check if Mock API is running
  console.log("[3/4] Checking Mock API server...");
  try {
    await httpGet("http://localhost:4000/health");
    console.log("  Mock API server is running.\n");
  } catch {
    console.log("  Mock API server NOT running. Please start it first:");
    console.log("    cd packages/mock-api && npx tsx src/server.ts\n");
    process.exit(1);
  }

  // Validate all endpoints
  console.log("[4/4] Validating endpoints...");
  const results: ValidationResult[] = [];

  for (const ep of ENDPOINTS) {
    const result: ValidationResult = {
      endpoint: ep.label,
      method: ep.method,
      path: ep.url,
      passed: true,
      errors: [],
      responseSnippet: "",
    };

    try {
      let response: { status: number; body: any };
      if (ep.method === "POST") {
        response = await httpPost(ep.url, ep.postBody ?? {});
      } else {
        response = await httpGet(ep.url);
      }

      result.responseSnippet = JSON.stringify(response.body).slice(0, 200);

      // HTTP status check
      if (response.status < 200 || response.status >= 300) {
        result.errors.push(`HTTP ${response.status} (expected 2xx)`);
        result.passed = false;
      }

      // Envelope structure check
      if (ep.url.includes("/health")) {
        // Health endpoint uses its own format
        if (!response.body.status) {
          result.errors.push("Health response missing status field");
          result.passed = false;
        }
      } else {
        const envErrors = validateEnvelopeStructure(response.body);
        if (envErrors.length > 0) {
          result.errors.push(...envErrors);
          result.passed = false;
        }

        // Detailed field checks for specific endpoints
        const fieldErrors = validateFieldTypes(response.body, ep.url);
        if (fieldErrors.length > 0) {
          result.errors.push(...fieldErrors);
          result.passed = false;
        }
      }

      // Ajv JSON Schema validation (for endpoints with defined schemas)
      const schemaName = ep.label.includes("/config") ? "Envelope_Config"
        : ep.label.includes("/system-status") ? "Envelope_SystemStatus"
        : ep.label.includes("/contracts") ? "Envelope_ContractList"
        : (ep.label.includes("/auth/nonce") ? "Envelope_Nonce"
        : (ep.label.includes("/auth/verify") ? "Envelope_Session"
        : (ep.label.includes("/wallets/") && ep.label.includes("summary") ? "Envelope_WalletSummary"
        : (ep.label.includes("/wallets/") && ep.label.includes("transactions") ? "Envelope_TxList"
        : (ep.label.includes("/quotes/buy") ? "Envelope_BuyQuote"
        : (ep.label.includes("/quotes/sell") ? "Envelope_SellQuote"
        : (ep.label.includes("/dividend/epochs/current") ? "Envelope_Epoch"
        : null))))))));

      if (schemaName) {
        const validator = envelopeSchemas[schemaName];
        if (validator) {
          const valid = validator(response.body);
          if (!valid) {
            const ajvErrors = formatAjvErrors(validator.errors);
            result.errors.push(...ajvErrors);
            result.passed = false;
          }
        }
      }

    } catch (err: unknown) {
      result.passed = false;
      result.errors.push(err instanceof Error ? err.message : String(err));
    }

    results.push(result);
  }

  // Print summary
  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;

  console.log("\n═══════════════════════════════════════════");
  console.log("RESULTS");
  console.log("═══════════════════════════════════════════\n");

  for (const r of results) {
    const icon = r.passed ? "✓" : "✗";
    console.log(`  ${icon} ${r.endpoint}`);
    for (const err of r.errors) {
      console.log(`       → ${err}`);
    }
  }

  console.log(`\n───────────────────────────────────────────`);
  console.log(`  Total: ${results.length} | Passed: ${passed} | Failed: ${failed}`);

  if (results.length === 0) {
    console.error(`  FATAL: Zero endpoints validated. CI gate fails closed.`);
    process.exit(1);
  }

  console.log(`  ${failed === 0 ? "ALL PASSED ✓" : `${failed} FAILED ✗`}`);
  console.log("═══════════════════════════════════════════\n");

  // Write evidence file
  const evidenceDir = resolve(__dirname, "../../../docs/evidence/PB-S0/P2-X03");
  try { execSync(`mkdir -p "${evidenceDir}"`, { shell: true }); } catch {}
  
  const reportPath = resolve(evidenceDir, "mock-schema-validation.json");
  const report = {
    validated_at: new Date().toISOString(),
    openapi_version: openapiDoc.info.version,
    total_endpoints: results.length,
    passed,
    failed,
    results: results.map(r => ({
      endpoint: r.endpoint,
      passed: r.passed,
      errors: r.errors,
    })),
  };
  writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`Evidence saved to: ${reportPath}`);

  process.exit(failed > 0 ? 1 : 0);
}

function writeFileSync(path: string, content: string) {
  const fs = require("fs");
  fs.writeFileSync(path, content);
}

main().catch(err => {
  console.error("Fatal error:", err);
  process.exit(1);
});
