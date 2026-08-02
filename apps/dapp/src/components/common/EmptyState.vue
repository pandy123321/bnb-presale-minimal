<!--
  PANGU2 DApp — EmptyState
  Displayed when a data set is empty (not loading, not errored).
  ═══════════════════════════════════════════
  Props:
    - icon: single emoji or character (optional)
    - title: heading text
    - description: secondary text (optional)
  Slots:
    - action (optional): button or CTA area
-->
<script setup lang="ts">
withDefaults(
  defineProps<{
    icon?: string;
    title: string;
    description?: string;
  }>(),
  {
    icon: undefined,
    description: undefined,
  },
);
</script>

<template>
  <div class="es">
    <span v-if="icon" class="es-icon">{{ icon }}</span>
    <b>{{ title }}</b>
    <small v-if="description">{{ description }}</small>
    <div v-if="$slots.action" class="es-action">
      <slot name="action" />
    </div>
  </div>
</template>

<style scoped>
.es {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 40px 20px;
  text-align: center;
}

.es-icon {
  font-size: 36px;
  margin-bottom: 4px;
}

.es b {
  font-size: 14px;
  color: var(--text);
}

.es small {
  font-size: 11px;
  color: var(--muted);
  max-width: 260px;
}

.es-action {
  margin-top: 8px;
}
</style>
