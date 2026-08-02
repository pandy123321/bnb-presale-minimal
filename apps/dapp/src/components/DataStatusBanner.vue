<script setup lang="ts">
import { useDataStore } from "@/stores/useData";

const data = useDataStore();
</script>

<template>
  <div v-if="data.needsWarning" class="banner" :class="data.dataStatus.toLowerCase()">
    <span class="banner-icon">{{ data.isMocked ? '◈' : data.isStale ? '⏳' : data.isDegraded ? '⚠' : '✕' }}</span>
    <div>
      <b>{{ data.dataStatus }}</b>
      <span>{{ data.isMocked ? '当前为模拟数据，不代表真实链上状态。' : data.isStale ? '数据可能已过期。' : data.isDegraded ? '部分服务不可用。' : '服务暂时不可用。' }}</span>
    </div>
  </div>
</template>

<style scoped>
.banner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 12px;
  margin-bottom: 11px;
  font-size: 10px;
}
.banner.mock_data { border: 1px solid rgba(243,163,75,.25); background: rgba(243,163,75,.055); color: #e6c28b; }
.banner.stale, .banner.degraded { border: 1px solid rgba(243,163,75,.25); background: rgba(243,163,75,.04); color: #d9c08a; }
.banner.unavailable { border: 1px solid rgba(255,116,125,.22); background: rgba(255,116,125,.04); color: #e5a2a8; }
.banner-icon { font-size: 16px; }
.banner b { display: block; font-size: 10px; }
.banner span { display: block; color: inherit; opacity: .8; margin-top: 2px; }
</style>
