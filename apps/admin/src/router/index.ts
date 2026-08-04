import { createRouter, createWebHistory } from "vue-router";
import { useAdminAuthStore } from "@/stores/useAdminAuth";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/login",
      name: "login",
      component: () => import("@/views/LoginView.vue"),
      meta: { guest: true },
    },
    { path: "/", name: "overview", component: () => import("@/views/OverviewView.vue"), meta: { requiresAuth: true } },
    { path: "/assets", name: "assets", component: () => import("@/views/AssetsView.vue"), meta: { requiresAuth: true } },
    { path: "/trades", name: "trades", component: () => import("@/views/TradesView.vue"), meta: { requiresAuth: true } },
    { path: "/buyback", name: "buyback", component: () => import("@/views/BuybackView.vue"), meta: { requiresAuth: true } },
    { path: "/staking", name: "staking", component: () => import("@/views/StakingView.vue"), meta: { requiresAuth: true } },
    { path: "/dividend", name: "dividend", component: () => import("@/views/DividendView.vue"), meta: { requiresAuth: true } },
    { path: "/governance", name: "governance", component: () => import("@/views/GovernanceView.vue"), meta: { requiresAuth: true } },
  ],
});

router.beforeEach(async (to, _from, next) => {
  if (to.meta.guest) return next();

  const auth = useAdminAuthStore();
  if (auth.isAuthenticated) return next();

  const valid = await auth.checkSession();
  if (valid) return next();

  return next("/login");
});

export default router;
