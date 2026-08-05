<script setup lang="ts">
withDefaults(defineProps<{ variant?: "demo" | "locked" | "open" }>(), { variant: "demo" });
</script>
<template><span class="tag-ui" :class="variant"><slot /></span></template>
<style scoped>
.tag-ui {
  display: inline-flex; align-items: center; min-height: 23px; padding: 0 8px;
  border-radius: 999px; font-size: 8px; font-weight: 850;
}
.tag-ui.demo { color: #F1D7A9; background: rgba(228, 185, 107, .07); border: 1px solid rgba(228, 185, 107, .17); }
.tag-ui.locked { color: #DFF8FF; background: rgba(76, 201, 240, .07); border: 1px solid rgba(76, 201, 240, .16); }
.tag-ui.open { color: #B9C3D5; background: rgba(255, 255, 255, .03); border: 1px solid var(--line); }
</style>
