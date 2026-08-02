<script setup lang="ts">
defineProps<{ message?: string }>();
const emit = defineEmits<{ retry: [] }>();
</script>

<template>
  <div class="empty">
    <div class="empty-icon">◈</div>
    <b>{{ message || '暂无数据' }}</b>
    <button v-if="emit" class="retry-btn" @click="emit('retry')">重新加载</button>
  </div>
</template>

<style scoped>
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 32px 16px;
  color: var(--muted);
  font-size: 11px;
  text-align: center;
}
.empty-icon { font-size: 28px; color: var(--gold2); opacity: .4; }
.empty b { font-size: 12px; font-weight: 600; }
.retry-btn {
  margin-top: 6px;
  padding: 6px 14px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: var(--panel);
  color: var(--gold2);
  font-size: 10px;
}
</style>
