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
    { label: string; subLabel: string; bg: string; border: string; color: string }
  > = {
    [DataStatus.MOCK_DATA]: {
      label: "",
      subLabel: "",
      bg: "",
      border: "",
      color: "",
    },
    [DataStatus.SYNCING]: {
      label: "同步中",
      subLabel: "正在索引链上数据，近期交易可能尚未显示。",
      bg: "rgba(37,194,255,0.08)",
      border: "rgba(37,194,255,0.22)",
      color: "var(--cyan)",
    },
    [DataStatus.LIVE]: {
      label: "Live",
      subLabel: "",
      bg: "",
      border: "",
      color: "",
    },
    [DataStatus.STALE]: {
      label: "数据滞后",
      subLabel: "数据未及时更新，价格可能不准确。",
      bg: "rgba(240,170,93,0.08)",
      border: "rgba(240,170,93,0.22)",
      color: "var(--orange)",
    },
    [DataStatus.DEGRADED]: {
      label: "服务降级",
      subLabel: "RPC 或后端连接质量下降。",
      bg: "rgba(255,107,125,0.08)",
      border: "rgba(255,107,125,0.22)",
      color: "var(--red)",
    },
    [DataStatus.UNAVAILABLE]: {
      label: "数据不可用",
      subLabel: "无法连接后端服务，数据可能无法访问。",
      bg: "rgba(255,107,125,0.12)",
      border: "rgba(255,107,125,0.3)",
      color: "var(--red)",
    },
  };
  return map[props.dataStatus] ?? map[DataStatus.UNAVAILABLE];
});
</script>

<template>
  <Transition name="banner-fade">
    <div v-if="show" class="status-banner" :style="{ background: config.bg, borderColor: config.border }">
      <svg class="icon" viewBox="0 0 24 24" width="20" height="20" :stroke="config.color" fill="none" stroke-width="2" stroke-linecap="round">
        <circle cx="12" cy="12" r="10"/>
        <line x1="12" y1="8" x2="12" y2="12"/>
        <line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
      <div class="body">
        <span class="label" :style="{ color: config.color }">{{ config.label }}</span>
        <span class="sublabel">{{ config.subLabel }}</span>
        <span v-if="blockNumber" class="block">区块 {{ blockNumber }}</span>
        <span v-if="ageFormatted" class="age">{{ ageFormatted }}</span>
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
