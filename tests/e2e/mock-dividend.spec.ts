/**
 * PANGU2 E2E — Dividend Slice
 * Validates: GET /dividend/epochs/current, GET /dividend/epochs/:id, proof endpoint
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";
const WALLET = "0x14791697260e4c9a71f18484c9f997b308e59325";

describe("E2E Dividend Slice", () => {
  it("GET /dividend/epochs/current returns current epoch", async () => {
    const res = await fetch(`${BASE}/dividend/epochs/current`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.epoch_id).toBeGreaterThan(0);
    expect(body.data.snapshot_block).toBeDefined();
    expect(body.data.total_dividend_raw).toBeDefined();
    expect(body.data.merkle_root).toMatch(/^0x/);
    expect(body.data.tiers).toHaveLength(4);
    expect(body.data.status).toBeDefined();
    expect(body.error).toBeNull();
  });

  it("GET /dividend/epochs/:id returns specific epoch", async () => {
    const res = await fetch(`${BASE}/dividend/epochs/28`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.epoch_id).toBe(28);
    expect(body.meta.data_status).toBe("MOCK_DATA");
  });

  it("GET /dividend/epochs/:id/proof/:addr returns proof", async () => {
    const res = await fetch(`${BASE}/dividend/epochs/28/proof/${WALLET}`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.amount_raw).toBeDefined();
    expect(Array.isArray(body.data.proof)).toBe(true);
    expect(body.data.claimed).toBe(false);
  });
});
