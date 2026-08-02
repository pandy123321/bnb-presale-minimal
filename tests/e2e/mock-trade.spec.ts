/**
 * PANGU2 E2E — Trade Slice
 * Validates: POST /quotes/buy, POST /quotes/sell
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";

describe("E2E Trade Slice", () => {
  it("POST /quotes/buy returns valid buy quote with 4% tax", async () => {
    const res = await fetch(`${BASE}/quotes/buy`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount_bnb_wei: "100000000000000000" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    const d = body.data;
    expect(d.amount_in_wei).toBe("100000000000000000");
    expect(d.tax_rate).toContain("4");
    expect(d.net_tokens_raw).toBeDefined();
    expect(d.min_receive_raw).toBeDefined();
    expect(d.quote_block).toBeDefined();
    expect(d.expires_at).toBeDefined();
    expect(d.source).toBe("mock");
    expect(body.meta.data_status).toBe("MOCK_DATA");
    expect(body.error).toBeNull();
  });

  it("POST /quotes/sell returns valid sell quote", async () => {
    const res = await fetch(`${BASE}/quotes/sell`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        amount_token_raw: "10000000000000000000000",
        wallet_address: "0x14791697260e4c9a71f18484c9f997b308e59325",
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    const d = body.data;
    expect(d.amount_in_raw).toBeDefined();
    expect(d.tax_rate).toBeDefined();
    expect(d.tax_destination).toBeDefined();
    expect(d.net_bnb_wei).toBeDefined();
    expect(d.min_receive_wei).toBeDefined();
    expect(d.source).toBe("mock");
    expect(body.error).toBeNull();
  });

  it("POST /quotes/buy rejects zero amount", async () => {
    const res = await fetch(`${BASE}/quotes/buy`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount_bnb_wei: "0" }),
    });
    expect(res.status).toBe(422);
  });
});
