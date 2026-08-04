<script setup lang="ts">
import { useRoute } from "vue-router";

const route = useRoute();
const navItems = [
  { id: "overview", label: "总览", sub: "资产、状态与风险", route: "/" },
  { id: "assets", label: "链上资产", sub: "合约、资金池与同步", route: "/assets" },
  { id: "trades", label: "交易与税费", sub: "交易、分桶与成本", route: "/trades" },
  { id: "buyback", label: "托底与回购", sub: "兑换、回购与Locker", route: "/buyback" },
  { id: "staking", label: "锁仓管理", sub: "奖励池、速率与仓位", route: "/staking" },
  { id: "dividend", label: "分红管理", sub: "Epoch、排名与领取", route: "/dividend" },
  { id: "governance", label: "系统治理", sub: "任务、权限与审计", route: "/governance" },
];

function isActive(item: typeof navItems[0]) {
  if (item.id === "overview") return route.path === "/";
  return route.path.startsWith(item.route);
}
</script>

<template>
  <aside class="sidebar">
    <div class="brand">
      <div class="logo">P2</div>
      <div><h1>PANGU2</h1><p>链上运营控制台</p></div>
    </div>
    <nav class="nav">
      <button v-for="item in navItems" :key="item.id" :class="{ active: isActive(item) }" @click="$router.push(item.route)">
        <span>{{ item.label }}</span>
      </button>
    </nav>
    <div class="side-block">
      <div class="side-status">
        <span>目标网络</span><b>BSC Testnet</b>
        <span>数据状态</span><b class="gold">MOCK_DATA</b>
        <span>同步高度</span><b>42,815,128</b>
      </div>
      <p class="side-note">后台不托管用户私钥，不修改用户资产、成本或分红结果。</p>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  height: 100vh;
  border-right: 1px solid var(--line);
  background: rgba(9,10,14,.96);
  padding: 20px 16px;
  display: flex;
  flex-direction: column;
}
.brand { display: flex; align-items: center; gap: 12px; padding: 0 6px 22px; border-bottom: 1px solid rgba(255,255,255,.055); }
.logo { width: 42px; height: 42px; display: grid; place-items: center; border: 1px solid rgba(214,173,95,.5); background: linear-gradient(145deg, rgba(214,173,95,.18), rgba(214,173,95,.035)); font-weight: 900; color: var(--gold2); letter-spacing: -1px; }
.brand h1 { font-size: 15px; margin: 0; font-weight: 750; }
.brand p { margin: 3px 0 0; color: var(--muted); font-size: 11px; }
.nav { display: grid; gap: 4px; margin-top: 18px; }
.nav button { height: 44px; border: 0; background: transparent; color: var(--muted); display: flex; align-items: center; gap: 12px; padding: 0 12px; text-align: left; border-left: 2px solid transparent; transition: .18s; }
.nav button:hover { background: rgba(255,255,255,.035); color: var(--text); }
.nav button.active { color: var(--gold2); background: linear-gradient(90deg, rgba(214,173,95,.095), transparent); border-left-color: var(--gold); }
.nav button span { font-size: 13px; font-weight: 650; }
.side-block { margin-top: auto; border-top: 1px solid rgba(255,255,255,.055); padding: 16px 6px 0; }
.side-status { display: grid; grid-template-columns: 1fr auto; gap: 4px 10px; align-items: center; }
.side-status span { color: var(--muted); font-size: 11px; }
.side-status b { font-size: 11px; }
.side-status b.gold { color: var(--gold2); }
.side-note { margin: 14px 0 0; color: var(--muted2); font-size: 10px; line-height: 1.6; }

@media (max-width: 820px) { .sidebar { display: none; } }
</style>
