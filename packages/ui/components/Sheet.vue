<script setup lang="ts">
import { ref } from "vue";

const emit = defineEmits(["close"]);
const visible = ref(false);
const title = ref("");

defineExpose({ open, close });

function open(t?: string) { title.value = t ?? ""; visible.value = true; }
function close() { visible.value = false; emit("close"); }
</script>
<template>
  <Teleport to="body">
    <div v-if="visible" class="overlay show" @click.self="close">
      <div class="sheet"><div class="handle"></div><div class="sheet-head"><h3>{{ title }}</h3><button class="icon-btn" @click="close" aria-label="Close">✕</button></div><slot /></div>
    </div>
  </Teleport>
</template>
<style scoped>
.overlay { position: fixed; inset: 0; z-index: 90; background: rgba(2, 4, 10, .74); display: flex; align-items: flex-end; justify-content: center; backdrop-filter: blur(6px); }
.sheet { width: min(100%, 430px); max-height: 92vh; overflow: auto; border-radius: 26px 26px 0 0; background: #0B101D; padding: 0 16px calc(18px + env(safe-area-inset-bottom)); box-shadow: 0 -25px 70px rgba(0, 0, 0, .45); }
.handle { width: 36px; height: 4px; border-radius: 99px; background: #2A354B; margin: 11px auto; }
.sheet-head { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; justify-content: space-between; padding: 8px 0 13px; background: rgba(11, 16, 29, .98); }
.sheet-head h3 { margin: 0; font-size: 16px; }
.icon-btn { width: 36px; height: 36px; border-radius: 11px; border: 1px solid var(--line); background: var(--surface); color: var(--text-2); }
</style>
