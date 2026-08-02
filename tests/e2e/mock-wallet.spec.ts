/**
 * PANGU2 E2E — Wallet Slice
 * Validates: GET /wallets/:addr/summary, GET /wallets/:addr/transactions
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";
const WALLET = "0x14791697260e4c9a71f18484c9f997b308e59325";

describe("E2E Wallet Slice", () => {
  it("GET /wallets/:addr/summary returns balance info", async () => {
    const res = await fetch(`${BASE}/wallets/${WALLET}/summary`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.address.toLowerCase()).toBe(WALLET);
    expect(body.data.balance_token_raw).toBeDefined();
    expect(body.data.balance_token_formatted).toBeDefined();
    expect(body.data.current_sell_tax_rate).toBeDefined();
    expect(body.data.rank).toBeGreaterThan(0);
    expect(body.error).toBeNull();
  });

  it("GET /wallets/:addr/transactions returns paginated list", async () => {
    const res = await fetch(`${BASE}/wallets/${WALLET}/transactions`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(2);
    expect(body.meta.current_page).toBe(1);
    expect(body.meta.total).toBeGreaterThanOrEqual(2);

    const tx = body.data[0];
    expect(tx.tx_hash).toMatch(/^0x[a-f0-9]{64}$/);
    expect(["buy", "sell", "claim", "buyback", "other"]).toContain(tx.type);
    expect(["pending", "confirmed", "failed", "replaced", "dropped", "reorged"]).toContain(tx.status);
  });
});
