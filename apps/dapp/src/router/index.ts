import { createRouter, createWebHistory } from "vue-router";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", name: "home", component: () => import("@/views/HomeView.vue") },
    { path: "/trade", name: "trade", component: () => import("@/views/TradeView.vue") },
    { path: "/dividend", name: "dividend", component: () => import("@/views/DividendView.vue") },
    { path: "/support", name: "support", component: () => import("@/views/SupportView.vue") },
    { path: "/me", name: "me", component: () => import("@/views/MeView.vue") },
  ],
});

export default router;
