<script setup lang="ts">
defineProps<{ message?: string }>();
const emit = defineEmits<{ retry: [] }>();
</script>

<template>
  <div class="error-box">
    <div class="error-icon">!</div>
    <b>{{ message || '加载失败' }}</b>
    <button class="retry-btn" @click="emit('retry')">重试</button>
  </div>
</template>

<style scoped>
.error-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 28px 16px;
  color: var(--red);
  font-size: 11px;
  text-align: center;
}
.error-icon { width: 36px; height: 36px; border-radius: 50%; border: 2px solid var(--red); display: grid; place-items: center; font-weight: 900; font-size: 16px; }
.error-box b { font-size: 12px; }
.retry-btn {
  margin-top: 6px;
  padding: 6px 14px;
  border: 1px solid rgba(255,116,125,.3);
  border-radius: 10px;
  background: rgba(255,116,125,.06);
  color: var(--red);
  font-size: 10px;
}
</style>
