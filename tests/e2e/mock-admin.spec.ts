/**
 * PANGU2 E2E — Admin Slice
 * Validates: POST /admin/login, GET /admin/dashboard, GET /admin/jobs, GET /admin/audit-logs
 */
import { describe, it, expect } from "vitest";

const BASE = "http://localhost:4000/admin-api/v1/projects/pangu2";
let token: string;

describe("E2E Admin Slice", () => {
  it("POST /auth/login returns admin token", async () => {
    const res = await fetch(`${BASE}/auth/login`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "admin@pangu2.io", password: "test" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.token).toBeDefined();
    expect(body.data.admin.id).toBe(1);
    expect(body.data.admin.role).toBe("SUPER_ADMIN");
    token = body.data.token;
  });

  it("GET /dashboard returns KPIs", async () => {
    const res = await fetch(`${BASE}/dashboard`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.total_bnb_raised_wei).toBeDefined();
    expect(body.data.unique_wallets).toBeGreaterThan(0);
    expect(body.data.active_epoch).toBeGreaterThan(0);
    expect(body.open_anomalies ?? body.data.open_anomalies).toBeDefined();
  });

  it("GET /jobs returns task list", async () => {
    const res = await fetch(`${BASE}/jobs`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThanOrEqual(1);
    const job = body.data[0];
    expect(job.name).toBeDefined();
    expect(job.status).toBeDefined();
  });

  it("GET /audit-logs returns paginated entries", async () => {
    const res = await fetch(`${BASE}/audit-logs`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);
    if (body.data.length > 0) {
      expect(body.data[0].id).toBeDefined();
      expect(body.data[0].action).toBeDefined();
      expect(body.data[0].result).toBeDefined();
    }
    if (body.meta) {
      expect(body.meta.current_page).toBeGreaterThanOrEqual(1);
    }
  });
});
