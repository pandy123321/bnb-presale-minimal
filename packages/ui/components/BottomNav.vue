<script setup lang="ts">
import { useRoute } from "vue-router";

interface NavTab { id: string; label: string; route: string; disabled?: boolean; badge?: number }

const route = useRoute();
const tabs: NavTab[] = [
  { id: "home", label: "Home", route: "/" },
  { id: "trade", label: "Trade", route: "/trade" },
  { id: "portfolio", label: "Portfolio", route: "/portfolio" },
];

function isActive(t: NavTab): boolean {
  return t.id === "home" ? route.path === "/" : route.path.startsWith(t.route);
}
</script>
<template>
  <nav class="bottom-nav">
    <button v-for="t in tabs" :key="t.id" class="nav-item" :class="{ active: isActive(t) }" :disabled="t.disabled" @click="$router.push(t.route)">
      <svg viewBox="0 0 24 24">
        <template v-if="t.id==='home'"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></template>
        <template v-if="t.id==='trade'"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></template>
        <template v-if="t.id==='portfolio'"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></template>
      </svg>
      <span>{{ t.label }}</span>
      <span v-if="t.badge" class="badge">{{ t.badge }}</span>
    </button>
  </nav>
</template>
<style scoped>
.bottom-nav {
  position: fixed; left: 50%; bottom: 0; z-index: 45; transform: translateX(-50%);
  width: min(100%, 430px); height: calc(var(--nav-h) + env(safe-area-inset-bottom));
  padding: 7px 42px env(safe-area-inset-bottom); display: grid; grid-template-columns: repeat(3, 1fr);
  background: rgba(7, 10, 19, .94); backdrop-filter: blur(18px); border-top: 1px solid rgba(255, 255, 255, .045);
}
.nav-item {
  position: relative; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 4px; color: #697790; font-size: 9px;
  border: 0; background: none; cursor: pointer;
}
.nav-item:disabled { opacity: .4; cursor: not-allowed; }
.nav-item svg { width: 20px; height: 20px; fill: none; stroke: currentColor; stroke-width: 1.8; }
.nav-item.active { color: #F5F8FC; }
.nav-item.active::after {
  content: ""; position: absolute; top: 0; width: 18px; height: 2px; border-radius: 2px;
  background: linear-gradient(90deg, var(--gold), var(--cyan));
}
.badge {
  position: absolute; top: -2px; right: calc(50% - 26px); min-width: 16px; height: 16px;
  border-radius: 99px; background: var(--red); color: #fff; font-size: 8px; font-weight: 800;
  display: grid; place-items: center; padding: 0 4px;
}
</style>
