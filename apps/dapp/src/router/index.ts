import { createRouter, createWebHistory } from "vue-router";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // ── V7.1 new pages (primary routes) ──
    { path: "/", name: "home", component: () => import("@/views/HomePage.vue") },
    { path: "/trade", name: "trade", component: () => import("@/views/TradePage.vue") },
    { path: "/portfolio", name: "portfolio", component: () => import("@/views/PortfolioPage.vue") },
    // ── Legacy pages (Phase 5 will delete) ──
    { path: "/legacy/home", name: "legacy-home", component: () => import("@/views/HomeView.vue") },
    { path: "/legacy/trade", name: "legacy-trade", component: () => import("@/views/TradeView.vue") },
    { path: "/legacy/dividend", name: "legacy-dividend", component: () => import("@/views/DividendView.vue") },
    { path: "/legacy/staking", name: "legacy-staking", component: () => import("@/views/StakingView.vue") },
    { path: "/legacy/support", name: "legacy-support", component: () => import("@/views/SupportView.vue") },
    { path: "/legacy/me", name: "legacy-me", component: () => import("@/views/MeView.vue") },
  ],
});

export default router;
