<script setup lang="ts">
import { useRoute } from "vue-router";
import { useAppStore } from "@/stores/useApp";

const route = useRoute();
const app = useAppStore();
const pageTitles: Record<string, { title: string; sub: string }> = {
  overview: { title: "运营总览", sub: "资产、运行状态与风险" },
  assets: { title: "链上资产与合约", sub: "合约、资金池与同步" },
  trades: { title: "交易与税费", sub: "交易、分桶与成本" },
  buyback: { title: "托底、回购与锁仓", sub: "兑换、回购与Locker" },
  dividend: { title: "前100名分红管理", sub: "Epoch、排名与领取" },
  governance: { title: "系统治理与审计", sub: "任务、权限与审计" },
};
const currentRoute = route.name as string || "overview";
const page = pageTitles[currentRoute] || pageTitles.overview;
</script>

<template>
  <header class="topbar">
    <div class="page-title"><h2>{{ page.title }}</h2><p>{{ page.sub }}</p></div>
    <div class="top-tools">
      <div class="env-pill">BSC TESTNET · 97</div>
      <div class="data-pill"><span :class="app.isLive ? 'dot' : 'dot warn'"></span>{{ app.statusLabel }}</div>
      <button class="operation-btn">操作中心</button>
    </div>
  </header>
</template>

<style scoped>
.topbar {
  height: 72px;
  position: sticky;
  top: 0;
  z-index: 30;
  background: rgba(8,9,12,.9);
  backdrop-filter: blur(18px);
  border-bottom: 1px solid rgba(255,255,255,.055);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}
.page-title h2 { margin: 0; font-size: 19px; font-weight: 720; }
.page-title p { margin: 4px 0 0; color: var(--muted); font-size: 11px; }
.top-tools { display: flex; align-items: center; gap: 10px; }
.env-pill, .data-pill { height: 34px; border: 1px solid var(--line); background: var(--panel); display: flex; align-items: center; gap: 8px; padding: 0 10px; font-size: 11px; }
.env-pill { color: var(--gold2); }
.data-pill { color: var(--green); }
.dot { width: 7px; height: 7px; border-radius: 50%; background: var(--green); box-shadow: 0 0 12px rgba(78,213,154,.55); display: inline-block; }
.dot.warn { background: var(--orange); box-shadow: 0 0 12px rgba(240,170,93,.55); }
.operation-btn { height: 36px; border: 1px solid rgba(214,173,95,.42); background: linear-gradient(145deg, rgba(214,173,95,.18), rgba(214,173,95,.05)); color: var(--gold2); padding: 0 12px; font-weight: 700; font-size: 12px; }

@media (max-width: 820px) {
  .topbar { height: 64px; padding: 0 14px; }
  .page-title h2 { font-size: 16px; }
}
</style>
