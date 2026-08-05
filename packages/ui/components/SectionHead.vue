<script setup lang="ts">
defineProps<{ title: string }>();
</script>
<template>
  <div class="section-head-ui">
    <h2>{{ title }}</h2>
    <slot name="actions" />
  </div>
</template>
<style scoped>
.section-head-ui {
  display: flex; align-items: center; gap: 9px; margin: 0 2px 11px;
}
.section-head-ui::before {
  content: ""; width: 16px; height: 2px; border-radius: 3px;
  background: linear-gradient(90deg, var(--gold), var(--cyan)); flex: 0 0 auto;
}
.section-head-ui h2 { margin: 0 auto 0 0; font-size: 15px; letter-spacing: -.01em; }
</style>
