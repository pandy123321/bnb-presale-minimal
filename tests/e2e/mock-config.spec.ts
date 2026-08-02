/**
 * PANGU2 E2E — Config Slice
 * Validates: GET /config, GET /system-status, GET /contracts
 */
import { describe, it, expect, beforeAll, afterAll } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";

describe("E2E Config Slice", () => {
  it("GET /config returns chain info", async () => {
    const res = await fetch(`${BASE}/config`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.project).toBe("PANGU2");
    expect(body.data.chain_id).toBe(31337);
    expect(body.data.rpc_status).toBe("OK");
    expect(body.meta.data_status).toBe("MOCK_DATA");
    expect(body.meta.schema_version).toBe("1.0.0");
    expect(body.error).toBeNull();
  });

  it("GET /system-status returns sync info", async () => {
    const res = await fetch(`${BASE}/system-status`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.latest_chain_block).toBeDefined();
    expect(body.data.last_scanned_block).toBeDefined();
    expect(typeof body.data.block_lag).toBe("number");
    expect(body.data.rpc_status).toBe("OK");
    expect(body.error).toBeNull();
  });

  it("GET /contracts returns array with valid fields", async () => {
    const res = await fetch(`${BASE}/contracts`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(4);
    const c = body.data[0];
    expect(c.name).toBeDefined();
    expect(c.address).toMatch(/^0x[a-fA-F0-9]{40}$/);
    expect(c.abi_version).toBe("1.0.0");
    expect(c.deployment_block).toBeDefined();
    expect(["ACTIVE", "PAUSED", "FINALIZED", "UNKNOWN"]).toContain(c.status);
  });
});
