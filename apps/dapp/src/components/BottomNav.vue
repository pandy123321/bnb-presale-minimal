<script setup lang="ts">
import { useRoute } from "vue-router";

const route = useRoute();
const tabs = [
  { id: "home", label: "首页", route: "/" },
  { id: "trade", label: "交易", route: "/trade" },
  { id: "dividend", label: "分红", route: "/dividend" },
  { id: "staking", label: "锁仓", route: "/staking" },
  { id: "me", label: "我的", route: "/me" },
];

function isActive(tab: typeof tabs[0]) {
  if (tab.id === "home") return route.path === "/";
  return route.path.startsWith(tab.route);
}
</script>

<template>
  <nav class="bottom-nav">
    <button v-for="tab in tabs" :key="tab.id" :class="{ active: isActive(tab) }" @click="$router.push(tab.route)">
      <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <!-- Home -->
        <path v-if="tab.id==='home'" d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
        <polyline v-if="tab.id==='home'" points="9 22 9 12 15 12 15 22"/>
        <!-- Trade (Swap) -->
        <polyline v-if="tab.id==='trade'" points="17 1 21 5 17 9"/>
        <path v-if="tab.id==='trade'" d="M3 11V9a4 4 0 0 1 4-4h14"/>
        <polyline v-if="tab.id==='trade'" points="7 23 3 19 7 15"/>
        <path v-if="tab.id==='trade'" d="M21 13v2a4 4 0 0 1-4 4H3"/>
        <!-- Dividend (Diamond) -->
        <path v-if="tab.id==='dividend'" d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14l-5-4.87 6.91-1.01z"/>
        <!-- Staking (Lock) -->
        <rect v-if="tab.id==='staking'" x="3" y="11" width="18" height="11" rx="2" ry="2"/>
        <path v-if="tab.id==='staking'" d="M7 11V7a5 5 0 0 1 10 0v4"/>
        <circle v-if="tab.id==='staking'" cx="12" cy="16" r="1"/>
        <!-- Me (User) -->
        <path v-if="tab.id==='me'" d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
        <circle v-if="tab.id==='me'" cx="12" cy="7" r="4"/>
      </svg>
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
  border-top: 1px solid rgba(87,116,176,.14);
  background: rgba(10,16,36,.95);
  backdrop-filter: blur(14px);
}

.bottom-nav button {
  border: 0;
  background: none;
  color: #5a6480;
  font-size: 8px;
  transition: color .2s;
  position: relative;
  padding-top: 2px;
}

.bottom-nav button.active {
  color: var(--cyan);
}

.bottom-nav button.active::before {
  content: '';
  position: absolute;
  top: -4px;
  left: 50%;
  transform: translateX(-50%);
  width: 18px;
  height: 1.5px;
  border-radius: 1px;
  background: var(--brand-gradient);
}

.nav-icon {
  display: block;
  width: 20px;
  height: 20px;
  margin: 0 auto 4px;
}
</style>
