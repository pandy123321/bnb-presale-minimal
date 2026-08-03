// PANGU2 Admin — Auth Store
// Session-based auth via Laravel web guard cookie.
import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { getCsrfToken, adminFetch } from "@/api/adminFetch";

interface AdminUser { id: number; name: string; email: string; role: "SUPER_ADMIN" | "ADMIN" | "OPERATOR" | "AUDITOR" | "VIEWER"; }

export const useAdminAuthStore = defineStore("adminAuth", () => {
  const admin = ref<AdminUser | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const isAuthenticated = computed(() => !!admin.value);
  const role = computed(() => admin.value?.role ?? null);
  const isSuperAdmin = computed(() => admin.value?.role === "SUPER_ADMIN");

  async function login(email: string, password: string): Promise<boolean> {
    loading.value = true; error.value = null;
    try {
      // Pre-fetch CSRF token before login POST
      await getCsrfToken();

      const res = await adminFetch("/auth/login", {
        method: "POST", body: JSON.stringify({ email, password }),
      });
      const body = await res.json();
      if (!res.ok || body.error) { error.value = body.error?.message ?? "Login failed"; return false; }
      admin.value = body.data.admin;
      return true;
    } catch (e: unknown) { error.value = e instanceof Error ? e.message : "Network error"; return false; }
    finally { loading.value = false; }
  }

  async function logout(): Promise<void> {
    admin.value = null;
    try { await adminFetch("/auth/logout", { method: "POST" }); } catch {}
  }

  async function checkSession(): Promise<boolean> {
    try {
      const res = await fetch(`/admin-api/v1/projects/pangu2/auth/me`, { credentials: "include" });
      if (!res.ok) { admin.value = null; return false; }
      const body = await res.json();
      admin.value = body.data.admin;
      return true;
    } catch { return false; }
  }

  return { admin, loading, error, isAuthenticated, role, isSuperAdmin, login, logout, checkSession };
});
