// PANGU2 Admin — Jobs API
import { ref, onMounted, onUnmounted } from "vue";

const ADMIN_API = "/admin-api/v1/projects/pangu2";

export interface JobInfo { name: string; status: string; run_id: string; last_error: string | null; processed: number; errors: number; last_run: string; }

export function useJobs() {
  const jobs = ref<JobInfo[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const retryingJob = ref<string | null>(null);
  const retryConfirm = ref<string | null>(null);
  const retryMsg = ref<string | null>(null);
  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetch() {
    loading.value = true; error.value = null;
    try {
      const res = await fetch(`${ADMIN_API}/jobs`, { credentials: "include" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = await res.json();
      jobs.value = (body.data ?? []) as JobInfo[];
    } catch (e: unknown) { error.value = e instanceof Error ? e.message : "Failed"; }
    finally { loading.value = false; }
  }

  function requestRetry(name: string) { retryConfirm.value = name; }
  function cancelRetry() { retryConfirm.value = null; }

  async function confirmRetry() {
    const name = retryConfirm.value; if (!name) return;
    retryConfirm.value = null; retryingJob.value = name; retryMsg.value = null;
    try {
      const key = `p2-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
      const res = await fetch(`${ADMIN_API}/jobs/${name}/retry`, {
        method: "POST", credentials: "include",
        headers: { "Idempotency-Key": key, "Content-Type": "application/json" },
      });
      const body = await res.json();
      if (!res.ok) { retryMsg.value = body?.error?.message ?? "Retry failed"; }
      else { retryMsg.value = `已排队 (${key.slice(0, 12)}...)`; await fetch(); }
    } catch (e: unknown) { retryMsg.value = e instanceof Error ? e.message : "Network error"; }
    finally { retryingJob.value = null; }
  }

  onMounted(() => { fetch(); timer = setInterval(fetch, 15_000); });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  const statusLabel = (s: string) =>
    ({ HEALTHY: "正常", RUNNING: "运行中", IDLE: "空闲", FAILED: "失败", DEGRADED: "降级" })[s] ?? s;

  return { jobs, loading, error, retryingJob, retryConfirm, retryMsg, requestRetry, cancelRetry, confirmRetry, statusLabel, fetch };
}
