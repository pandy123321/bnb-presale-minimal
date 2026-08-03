// PANGU2 Admin — CSRF-protected fetch helper
// Provides unified POST/PUT/PATCH/DELETE with automated CSRF token management.

const ADMIN_API = "/admin-api/v1/projects/pangu2";

let csrfToken: string | null = null;

export async function getCsrfToken(): Promise<string> {
  const res = await fetch(`${ADMIN_API}/csrf-token`, { credentials: "include" });
  if (!res.ok) throw new Error(`CSRF token fetch failed: ${res.status}`);
  const body = await res.json();
  csrfToken = body.data?.csrf_token ?? null;
  if (!csrfToken) throw new Error("CSRF token missing in response");
  return csrfToken;
}

export async function adminFetch(input: string, init?: RequestInit): Promise<Response> {
  // Ensure CSRF token is available; retry once on 419
  if (!csrfToken) {
    try { csrfToken = await getCsrfToken(); } catch { /* will fail on first request */ }
  }

  const headers = new Headers(init?.headers);
  headers.set("Accept", "application/json");
  if (!headers.has("Content-Type") && (init?.method ?? "GET") !== "GET") {
    headers.set("Content-Type", "application/json");
  }
  if (csrfToken) headers.set("X-CSRF-TOKEN", csrfToken);

  let res = await fetch(`${ADMIN_API}${input}`, { ...init, headers, credentials: "include" });

  // Retry once on CSRF expiry (419)
  if (res.status === 419) {
    csrfToken = await getCsrfToken();
    headers.set("X-CSRF-TOKEN", csrfToken);
    res = await fetch(`${ADMIN_API}${input}`, { ...init, headers, credentials: "include" });
  }

  return res;
}
