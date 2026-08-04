<script setup lang="ts">
import { useRoute } from "vue-router";

const route = useRoute();
const tabs = [
  { id: "home", label: "首页", icon: "⌂", route: "/" },
  { id: "trade", label: "交易", icon: "⇄", route: "/trade" },
  { id: "dividend", label: "分红", icon: "◇", route: "/dividend" },
  { id: "staking", label: "锁仓", icon: "⬡", route: "/staking" },
  { id: "me", label: "我的", icon: "○", route: "/me" },
];

function isActive(tab: typeof tabs[0]) {
  if (tab.id === "home") return route.path === "/";
  return route.path.startsWith(tab.route);
}
</script>

<template>
  <nav class="bottom-nav">
    <button v-for="tab in tabs" :key="tab.id" :class="{ active: isActive(tab) }" @click="$router.push(tab.route)">
      <span class="nav-icon">{{ tab.icon }}</span>
      <span>{{ tab.label }}</span>
    </button>
  </nav>
</template>

<style scoped>
.bottom-nav {
  position: fixed;
  left: 50%;
  bottom: 0;
  z-index: 36;
  transform: translateX(-50%);
  width: min(100%, 430px);
  height: calc(70px + env(safe-area-inset-bottom));
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  padding: 8px 8px env(safe-area-inset-bottom);
  border-top: 1px solid rgba(255,255,255,.06);
  background: rgba(10,12,16,.95);
  backdrop-filter: blur(18px);
}

.bottom-nav button {
  border: 0;
  background: none;
  color: #6e7480;
  font-size: 8px;
}

.bottom-nav button.active { color: var(--gold2); }

.nav-icon {
  display: block;
  font-size: 19px;
  line-height: 23px;
}
</style>
