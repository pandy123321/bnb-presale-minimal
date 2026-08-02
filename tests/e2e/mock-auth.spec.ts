/**
 * PANGU2 E2E — Auth Slice
 * Validates: POST /auth/nonce, POST /auth/verify, POST /auth/logout
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/api/v1/projects/pangu2";
const WALLET = "0x14791697260e4c9a71f18484c9f997b308e59325";

describe("E2E Auth Slice", () => {
  let nonce: string;

  it("POST /auth/nonce returns nonce + message", async () => {
    const res = await fetch(`${BASE}/auth/nonce`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ wallet_address: WALLET }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.nonce).toBeDefined();
    expect(body.data.message).toContain("PANGU2");
    expect(body.data.expires_at).toBeDefined();
    expect(body.meta.data_status).toBe("MOCK_DATA");
    nonce = body.data.nonce;
  });

  it("POST /auth/verify returns session token", async () => {
    const res = await fetch(`${BASE}/auth/verify`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ wallet_address: WALLET, signature: "0x" + "ab".repeat(65) }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.token).toBeDefined();
    expect(body.data.wallet_address.toLowerCase()).toBe(WALLET);
    expect(body.data.expires_at).toBeDefined();
  });

  it("POST /auth/logout succeeds", async () => {
    const res = await fetch(`${BASE}/auth/logout`, { method: "POST" });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data).toBeDefined();
  });
});
