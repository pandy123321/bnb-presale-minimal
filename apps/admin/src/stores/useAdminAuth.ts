// ═══════════════════════════════════════════
// PANGU2 Admin — Auth Store
// Handles admin login session and role info.
// Hard rules: no sensitive credentials stored; backend is authoritative.
// ═══════════════════════════════════════════

import { defineStore } from "pinia";
import { ref, computed } from "vue";

const ADMIN_API = "/admin-api/v1/projects/pangu2";

interface AdminUser {
  id: number;
  name: string;
  email: string;
  role: "SUPER_ADMIN" | "ADMIN" | "OPERATOR" | "AUDITOR" | "VIEWER";
}

export const useAdminAuthStore = defineStore("adminAuth", () => {
  const token = ref<string | null>(localStorage.getItem("p2_admin_token"));
  const admin = ref<AdminUser | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const isAuthenticated = computed(() => !!token.value && !!admin.value);
  const role = computed(() => admin.value?.role ?? null);
  const isSuperAdmin = computed(() => admin.value?.role === "SUPER_ADMIN");

  async function login(email: string, password: string): Promise<boolean> {
    loading.value = true;
    error.value = null;
    try {
      const res = await fetch(`${ADMIN_API}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const body = await res.json();

      if (!res.ok || body.error) {
        error.value = body.error?.message ?? "Login failed";
        return false;
      }

      token.value = body.data.token;
      admin.value = body.data.admin;
      localStorage.setItem("p2_admin_token", body.data.token);
      return true;
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Network error";
      return false;
    } finally {
      loading.value = false;
    }
  }

  function logout(): void {
    token.value = null;
    admin.value = null;
    localStorage.removeItem("p2_admin_token");
  }

  /** Check if session is still valid on app start. */
  async function checkSession(): Promise<boolean> {
    if (!token.value) return false;
    try {
      const res = await fetch(`${ADMIN_API}/auth/me`, {
        headers: { Authorization: `Bearer ${token.value}` },
      });
      if (!res.ok) { logout(); return false; }
      const body = await res.json();
      admin.value = body.data;
      return true;
    } catch {
      return false;
    }
  }

  return { token, admin, loading, error, isAuthenticated, role, isSuperAdmin, login, logout, checkSession };
});
