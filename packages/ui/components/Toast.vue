<script setup lang="ts">
import { ref, onUnmounted } from "vue";
const visible = ref(false); const message = ref("");
let timer: ReturnType<typeof setTimeout> | null = null;
function show(msg: string, ms = 2500): void { message.value = msg; visible.value = true; if (timer) clearTimeout(timer); timer = setTimeout(() => { visible.value = false; }, ms); }
function hide(): void { visible.value = false; if (timer) clearTimeout(timer); }
onUnmounted(() => { if (timer) clearTimeout(timer); });
defineExpose<{ show: (msg: string, ms?: number) => void; hide: () => void }>({ show, hide });
</script>
<template>
  <Transition name="toast-fade"><div v-if="visible" class="toast show">{{ message }}</div></Transition>
</template>
<style scoped>
.toast { position: fixed; z-index: 110; left: 50%; bottom: calc(var(--nav-h) + 16px + env(safe-area-inset-bottom)); transform: translate(-50%, 14px); width: calc(100% - 40px); max-width: 360px; padding: 12px 14px; border-radius: 13px; background: #111A2C; border: 1px solid var(--line); font-size: 10px; line-height: 1.45; opacity: 0; pointer-events: none; transition: .2s; box-shadow: 0 18px 42px rgba(0,0,0,.35); }
.toast.show { opacity: 1; transform: translate(-50%, 0); }
</style>
