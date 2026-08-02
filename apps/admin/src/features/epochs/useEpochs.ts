// PANGU2 Admin — Epoch API
import { ref, onMounted, onUnmounted } from "vue";
import type { EpochInfo, DividendTier, Envelope } from "@pangu2/api-types";
import { useAdminAuthStore } from "@/stores/useAdminAuth";

const ADMIN_API = "/admin-api/v1/projects/pangu2";
const API_BASE = "/api/v1/projects/pangu2";

async function adminFetch<T>(path: string): Promise<Envelope<T>> {
  const auth = useAdminAuthStore();
  const res = await fetch(`${ADMIN_API}${path}`, {
    headers: { Authorization: `Bearer ${auth.token}`, "Content-Type": "application/json" },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<Envelope<T>>;
}

async function publicFetch<T>(path: string): Promise<Envelope<T>> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<Envelope<T>>;
}

export function useEpochs() {
  const epochs = ref<EpochInfo[]>([]);
  const current = ref<EpochInfo | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);
  let timer: ReturnType<typeof setInterval> | null = null;

  async function fetch() {
    loading.value = true; error.value = null;
    try {
      const [cur, dash] = await Promise.all([
        publicFetch<EpochInfo>("/dividend/epochs/current"),
        adminFetch<{ current_epoch_id: number }>("/dashboard"),
      ]);
      current.value = cur.data;
      // Build mock epoch list from dashboard
      const count = dash.data?.current_epoch_id ?? current.value?.epoch_id ?? 28;
      epochs.value = Array.from({ length: Math.min(count, 10) }, (_, i) => ({
        ...cur.data,
        epoch_id: count - i,
        status: i === 0 ? cur.data.status : (i < 3 ? "claim_open" : "closed"),
      })) as EpochInfo[];
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : "Failed";
    } finally { loading.value = false; }
  }

  onMounted(() => { fetch(); timer = setInterval(fetch, 60_000); });
  onUnmounted(() => { if (timer) clearInterval(timer); });

  const tiers: DividendTier[] = [
    { name: "Tier 1", rank_range: "1-10", share_percent: 35 },
    { name: "Tier 2", rank_range: "11-30", share_percent: 25 },
    { name: "Tier 3", rank_range: "31-60", share_percent: 25 },
    { name: "Tier 4", rank_range: "61-100", share_percent: 15 },
  ];

  const statusLabel = (s: string) =>
    ({ pending: "待快照", snapshot_complete: "快照完成", proof_generated: "Proof就绪", claim_open: "领取开放", closed: "已关闭" })[s] ?? s;

  return { epochs, current, loading, error, tiers, statusLabel, fetch };
}
