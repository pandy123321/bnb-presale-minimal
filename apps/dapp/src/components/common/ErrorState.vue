<!--
  PANGU2 DApp — ErrorState
  Displayed when a data fetch has failed.
  ═══════════════════════════════════════════
  Props:
    - message: error message (required)
    - code: error code (optional)
    - retryable: whether retry is available
    - onRetry: callback for retry button (optional)
    - compact: smaller variant for inline use
-->
<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    message: string;
    code?: string;
    retryable?: boolean;
    compact?: boolean;
  }>(),
  {
    code: undefined,
    retryable: false,
    compact: false,
  },
);

const emit = defineEmits<{
  retry: [];
}>();
</script>

<template>
  <div class="err" :class="{ compact }">
    <div class="err-top">
      <span class="err-icon">!</span>
      <div class="err-body">
        <b>{{ code ? `[${code}] ${message}` : message }}</b>
        <small v-if="retryable && !compact">This error is temporary. You can try again.</small>
      </div>
    </div>
    <button type="button" v-if="retryable" class="retry-btn" @click="emit('retry')">
      Retry
    </button>
  </div>
</template>

<style scoped>
.err {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px;
  border-radius: var(--radius);
  border: 1px solid rgba(255, 116, 125, 0.18);
  background: rgba(255, 116, 125, 0.04);
  font-size: 12px;
  line-height: 1.4;
}

.err.compact {
  padding: 10px 12px;
  flex-direction: row;
  align-items: center;
}

.err-top {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}

.err-icon {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: rgba(255, 116, 125, 0.12);
  color: var(--red);
  display: grid;
  place-items: center;
  font-weight: 900;
  font-size: 14px;
  flex-shrink: 0;
}

.err-body {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.err-body b {
  color: var(--red);
  word-break: break-word;
}

.err-body small {
  color: var(--muted);
}

.retry-btn {
  align-self: flex-start;
  height: 32px;
  padding: 0 14px;
  border: 1px solid var(--line);
  background: rgba(255, 255, 255, 0.04);
  border-radius: 8px;
  font-size: 11px;
  font-weight: 700;
  color: var(--text);
  transition: background 0.15s;
}

.compact .retry-btn {
  margin-left: auto;
  flex-shrink: 0;
}

.retry-btn:hover {
  background: rgba(255, 255, 255, 0.08);
}
</style>
