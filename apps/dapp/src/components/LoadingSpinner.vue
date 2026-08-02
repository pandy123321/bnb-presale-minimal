<script setup lang="ts">
</script>

<template>
  <div class="loading">
    <div class="spinner"></div>
    <span v-if="$slots.default"><slot /></span>
  </div>
</template>

<style scoped>
.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 28px;
  color: var(--muted);
  font-size: 11px;
}
.spinner {
  width: 28px;
  height: 28px;
  border: 2.5px solid rgba(216,170,81,.15);
  border-top-color: var(--gold);
  border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
