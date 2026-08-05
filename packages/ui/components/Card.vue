<script setup lang="ts">
withDefaults(defineProps<{ variant?: "default" | "soft" }>(), { variant: "default" });
</script>
<template><div class="card-ui" :class="variant"><slot /></div></template>
<style scoped>
.card-ui {
  border: 0;
  border-radius: var(--radius);
  background: linear-gradient(155deg, rgba(17, 26, 43, .98), rgba(10, 16, 28, .98));
  padding: var(--module-pad);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, .045), var(--shadow);
}
.card-ui.soft {
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, .04);
  background: rgba(13, 20, 34, .78);
}
</style>
