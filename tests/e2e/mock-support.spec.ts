/**
 * PANGU2 E2E — Support Slice
 * Validates: GET /buybacks, GET /locker/batches
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";

describe("E2E Support Slice", () => {
  it("GET /buybacks returns buyback history with pagination", async () => {
    const res = await fetch(`${BASE}/buybacks`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(1);
    if (body.meta) {
      expect(body.meta.current_page).toBeGreaterThanOrEqual(1);
      expect(body.meta.total).toBeGreaterThanOrEqual(1);
    }
    const bb = body.data[0];
    expect(bb.batch_id).toBeGreaterThan(0);
    expect(bb.amount_bnb_wei).toBeDefined();
    expect(bb.tokens_raw).toBeDefined();
    expect(body.error).toBeNull();
  });

  it("GET /locker/batches returns locked batches", async () => {
    const res = await fetch(`${BASE}/locker/batches`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(1);
    const lb = body.data[0];
    expect(lb.tokens_raw).toBeDefined();
    expect(lb.locked_until).toBeDefined();
    expect(lb.duration_days).toBe(365);
    expect(body.error).toBeNull();
  });
});
