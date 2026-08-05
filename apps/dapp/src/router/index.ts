import { createRouter, createWebHistory } from "vue-router";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // ── V7.1 pages ──
    { path: "/", name: "home", component: () => import("@/views/HomePage.vue") },
    { path: "/trade", name: "trade", component: () => import("@/views/TradePage.vue") },
    { path: "/portfolio", name: "portfolio", component: () => import("@/views/PortfolioPage.vue") },
  ],
});

export default router;
