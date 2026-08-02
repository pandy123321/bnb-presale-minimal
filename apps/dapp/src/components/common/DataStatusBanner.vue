<!--
  PANGU2 DApp — DataStatusBanner
  Displays a prominent banner when data_status is NOT LIVE.
  ═══════════════════════════════════════════
  Props:
    - dataStatus: the current DataStatus enum value
    - blockNumber: last known block number (optional)
    - ageFormatted: human-readable time since last update (optional)
  Slots:
    - default (optional): custom action button area
-->
<script setup lang="ts">
import { computed } from "vue";
import { DataStatus } from "@pangu2/api-types";
import type { DataStatus as DataStatusType } from "@pangu2/api-types";

const props = withDefaults(
  defineProps<{
    dataStatus: DataStatusType;
    blockNumber?: string | null;
    ageFormatted?: string | null;
  }>(),
  {
    blockNumber: null,
    ageFormatted: null,
  },
);

const show = computed(() => props.dataStatus !== DataStatus.LIVE);

const config = computed(() => {
  const map: Record<
    DataStatusType,
    { label: string; subLabel: string; bg: string; border: string; color: string; icon: string }
  > = {
    [DataStatus.MOCK_DATA]: {
      label: "Mock Data",
      subLabel: "Showing simulated data. Not connected to live chain.",
      bg: "rgba(243,163,75,0.08)",
      border: "rgba(243,163,75,0.22)",
      color: "var(--orange)",
      icon: "🛠",
    },
    [DataStatus.SYNCING]: {
      label: "Syncing",
      subLabel: "Indexing chain data. Recent transactions may not appear yet.",
      bg: "rgba(106,169,255,0.08)",
      border: "rgba(106,169,255,0.22)",
      color: "var(--blue)",
      icon: "⟳",
    },
    [DataStatus.LIVE]: {
      label: "Live",
      subLabel: "",
      bg: "",
      border: "",
      color: "",
      icon: "",
    },
    [DataStatus.STALE]: {
      label: "Stale",
      subLabel: "Data is out of date. Prices may be inaccurate.",
      bg: "rgba(243,163,75,0.08)",
      border: "rgba(243,163,75,0.22)",
      color: "#f3a34b",
      icon: "⏳",
    },
    [DataStatus.DEGRADED]: {
      label: "Degraded",
      subLabel: "RPC or backend connection is degraded.",
      bg: "rgba(255,116,125,0.08)",
      border: "rgba(255,116,125,0.22)",
      color: "var(--red)",
      icon: "⚠",
    },
    [DataStatus.UNAVAILABLE]: {
      label: "Unavailable",
      subLabel: "Cannot reach the backend. Data may be inaccessible.",
      bg: "rgba(255,116,125,0.12)",
      border: "rgba(255,116,125,0.3)",
      color: "var(--red)",
      icon: "⊘",
    },
  };
  return map[props.dataStatus] ?? map[DataStatus.UNAVAILABLE];
});
</script>

<template>
  <Transition name="banner-fade">
    <div v-if="show" class="status-banner" :style="{ background: config.bg, borderColor: config.border }">
      <span class="icon">{{ config.icon }}</span>
      <div class="body">
        <span class="label" :style="{ color: config.color }">{{ config.label }}</span>
        <span class="sublabel">{{ config.subLabel }}</span>
        <span v-if="blockNumber" class="block">Block: {{ blockNumber }}</span>
        <span v-if="ageFormatted" class="age">{{ ageFormatted }} ago</span>
      </div>
      <slot />
    </div>
  </Transition>
</template>

<style scoped>
.banner-fade-enter-active,
.banner-fade-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}
.banner-fade-enter-from,
.banner-fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

.status-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid;
  border-radius: 12px;
  margin: 0 14px 8px;
  font-size: 12px;
  line-height: 1.4;
}

.icon {
  font-size: 20px;
  flex-shrink: 0;
}

.body {
  flex: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: baseline;
}

.label {
  font-weight: 900;
  font-size: 12px;
  letter-spacing: 0.04em;
}

.sublabel {
  color: var(--muted);
  font-size: 11px;
}

.block,
.age {
  font-size: 10px;
  color: var(--muted);
  background: rgba(255, 255, 255, 0.04);
  padding: 1px 6px;
  border-radius: 6px;
}
</style>
