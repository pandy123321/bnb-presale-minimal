<script setup lang="ts">
withDefaults(defineProps<{ variant?: "primary" | "secondary" | "text"; disabled?: boolean }>(), { variant: "primary", disabled: false });
</script>
<template><button type="button" class="btn-ui" :class="[variant, { disabled }]" :disabled="disabled"><slot /></button></template>
<style scoped>
.btn-ui {
  min-height: 48px; border-radius: var(--control-radius); padding: 0 16px;
  border: 1px solid transparent; font-size: 12px; font-weight: 850; transition: .16s;
}
.btn-ui.primary {
  background: linear-gradient(105deg, var(--blue), #3B91EF 58%, var(--cyan));
  color: white; box-shadow: 0 10px 24px rgba(46, 107, 230, .20);
}
.btn-ui.secondary { background: var(--surface); border-color: var(--line); color: var(--text); }
.btn-ui.text { min-height: 38px; background: none; color: var(--text-2); padding: 0 8px; }
.btn-ui.disabled { opacity: .46; box-shadow: none; cursor: not-allowed; }
.btn-ui:active:not(.disabled) { transform: translateY(1px); }
.btn-ui:focus-visible { outline: 2px solid rgba(76, 201, 240, .55); outline-offset: 2px; }
</style>
