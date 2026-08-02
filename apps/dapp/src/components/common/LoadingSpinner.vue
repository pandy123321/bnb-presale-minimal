<!--
  PANGU2 DApp — LoadingSpinner
  Centered loading indicator with optional label.
  ═══════════════════════════════════════════
  Props:
    - label: text shown below the spinner (optional)
    - size: 'sm' | 'md' (default 'md')
-->
<script setup lang="ts">
withDefaults(
  defineProps<{
    label?: string;
    size?: "sm" | "md";
  }>(),
  {
    label: undefined,
    size: "md",
  },
);
</script>

<template>
  <div class="spinner-wrap" :class="size">
    <div class="spinner" />
    <span v-if="label" class="label">{{ label }}</span>
  </div>
</template>

<style scoped>
.spinner-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 40px 20px;
}

.spinner-wrap.sm {
  padding: 16px 10px;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid rgba(255, 255, 255, 0.12);
  border-top-color: var(--gold);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

.spinner-wrap.sm .spinner {
  width: 22px;
  height: 22px;
  border-width: 2px;
}

.label {
  font-size: 12px;
  color: var(--muted);
  text-align: center;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
