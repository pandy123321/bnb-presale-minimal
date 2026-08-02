// ═══════════════════════════════════════════
// PANGU2 DApp — useDividend Composable
// 对接 /dividend/epochs/current 和 /dividend/epochs/{id}/proof/{addr} API
// 硬规则: Proof 来自 API，不由前端计算
// ═══════════════════════════════════════════

import { computed, type Ref } from "vue";
import type { EnvelopeMeta, EpochInfo } from "@pangu2/api-types";
import { DataStatus } from "@pangu2/api-types";
import { useAsyncData, fetchGet } from "@/api";
import type { AsyncDataState } from "@/api";

export interface DividendProof {
  epoch_id: number;
  address: string;
  amount_raw: string;
  proof: string[];
  claimed: boolean;
}

export function useDividend(address: Ref<string | null>) {
  // ── 当前 Epoch ──────────────────────────
  const epoch = useAsyncData<EpochInfo>(
    (signal) => fetchGet<EpochInfo>("/v1/projects/pangu2/dividend/epochs/current", signal),
    { immediate: true, refreshIntervalMs: 60_000 },
  );

  // ── 用户 Proof ───────────────────────────
  const proof = useAsyncData<DividendProof>(
    (signal) => {
      if (!address.value) throw new Error("no_address");
      return fetchGet<DividendProof>(
        `/v1/projects/pangu2/dividend/epochs/current/proof/${address.value}`,
        signal,
      );
    },
    { immediate: false },
  );

  // ── 派生 ─────────────────────────────────
  const isLoading = computed(() => epoch.state.value.isLoading || proof.state.value.isLoading);
  const isMockData = computed(() => epoch.state.value.dataStatus === DataStatus.MOCK_DATA);
  const epochStatus = computed(() => epoch.state.value.data?.status ?? "unknown");
  const claimOpen = computed(() => epochStatus.value === "claim_open");
  const isClaimable = computed(() => claimOpen.value && !proof.state.value.data?.claimed);

  const myRank = computed(() => {
    // rank from wallet summary (injected from parent or separate store context)
    return null;
  });

  function fetchProof() {
    if (address.value) proof.execute();
  }

  return {
    epoch,
    proof,
    isLoading,
    isMockData,
    epochStatus,
    claimOpen,
    isClaimable,
    fetchProof,
  };
}
