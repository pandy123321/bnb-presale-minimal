<!--
  PANGU2 DApp — ErrorBoundary
  Catches render errors in children and displays a recoverable error UI.
  DOES NOT catch async errors (use try/catch in your component logic).
  ═══════════════════════════════════════════
  Props:
    - fallbackMessage: text shown when an error occurs
  Slots:
    - default: the slot that may throw
-->
<script setup lang="ts">
import { ref, onErrorCaptured } from "vue";

defineProps<{
  fallbackMessage?: string;
}>();

const hasError = ref(false);
const errorMessage = ref("");

onErrorCaptured((err: unknown) => {
  hasError.value = true;
  errorMessage.value = err instanceof Error ? err.message : "An unexpected error occurred.";
  return false; // prevent propagation
});

function reset(): void {
  hasError.value = false;
  errorMessage.value = "";
}
</script>

<template>
  <div v-if="hasError" class="eb">
    <div class="eb-icon">!</div>
    <div class="eb-body">
      <b>{{ fallbackMessage ?? "Something went wrong" }}</b>
      <small>{{ errorMessage }}</small>
    </div>
    <button type="button" class="eb-btn" @click="reset">Retry</button>
  </div>
  <slot v-else />
</template>

<style scoped>
.eb {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px;
  border-radius: var(--radius);
  border: 1px solid rgba(255, 116, 125, 0.22);
  background: rgba(255, 116, 125, 0.06);
  margin: 11px 0;
  font-size: 12px;
  line-height: 1.4;
}

.eb-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(255, 116, 125, 0.15);
  color: var(--red);
  display: grid;
  place-items: center;
  font-weight: 900;
  font-size: 16px;
  flex-shrink: 0;
}

.eb-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.eb-body b {
  color: var(--red);
}

.eb-body small {
  color: var(--muted);
  word-break: break-word;
}

.eb-btn {
  height: 30px;
  padding: 0 12px;
  border: 1px solid var(--line);
  background: rgba(255, 255, 255, 0.04);
  border-radius: 8px;
  font-size: 11px;
  font-weight: 700;
  color: var(--text);
  flex-shrink: 0;
  transition: background 0.15s;
}

.eb-btn:hover {
  background: rgba(255, 255, 255, 0.08);
}
</style>
