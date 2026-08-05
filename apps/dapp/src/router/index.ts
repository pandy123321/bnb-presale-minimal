import { createRouter, createWebHistory } from "vue-router";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // ── V7.1 new pages ──
    { path: "/", name: "home", component: () => import("@/views/HomePage.vue") },
    { path: "/trade-v2", name: "trade-v2", component: () => import("@/views/TradePage.vue") },
    { path: "/portfolio", name: "portfolio", component: () => import("@/views/PortfolioPage.vue") },
    // ── Legacy pages (preserved) ──
    { path: "/old-home", name: "old-home", component: () => import("@/views/HomeView.vue") },
    { path: "/trade", name: "trade", component: () => import("@/views/TradeView.vue") },
    { path: "/dividend", name: "dividend", component: () => import("@/views/DividendView.vue") },
    { path: "/staking", name: "staking", component: () => import("@/views/StakingView.vue") },
    { path: "/support", name: "support", component: () => import("@/views/SupportView.vue") },
    { path: "/me", name: "me", component: () => import("@/views/MeView.vue") },
  ],
});

export default router;
