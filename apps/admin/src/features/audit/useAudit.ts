// PANGU2 Admin — Audit API
import { ref, onMounted, onUnmounted } from "vue";
import { useAdminAuthStore } from "@/stores/useAdminAuth";

const ADMIN_API = "/admin-api/v1/projects/pangu2";

export interface AuditEntry { id: number; action: string; target_type: string | null; admin_email: string; admin_role: string; ip_address: string | null; result: string; created_at: string; }

export function useAudit() {
  const logs = ref<AuditEntry[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const filterAction = ref("");
  const filterAdmin = ref("");
  const page = ref(1);
  const total = ref(0);
  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetch() {
    loading.value = true; error.value = null;
    try {
      const auth = useAdminAuthStore();
      const params = new URLSearchParams({ per_page: "25", page: String(page.value) });
      if (filterAction.value) params.set("action", filterAction.value);
      if (filterAdmin.value) params.set("administrator", filterAdmin.value);
      const res = await fetch(`${ADMIN_API}/audit-logs?${params}`, { headers: { Authorization: `Bearer ${auth.token}` } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = await res.json();
      logs.value = (body.data ?? []) as AuditEntry[];
      total.value = body.meta?.total ?? logs.value.length;
    } catch (e: unknown) { error.value = e instanceof Error ? e.message : "Failed"; }
    finally { loading.value = false; }
  }

  onMounted(() => { fetch(); timer = setInterval(fetch, 30_000); });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  const resultLabel = (r: string) => (r === "SUCCESS" ? "成功" : r === "FAILED" ? "失败" : r);

  return { logs, loading, error, filterAction, filterAdmin, page, total, resultLabel, fetch };
}
