<script setup lang="ts">
import { useWalletStore } from "@/stores/useWallet";
const wallet = useWalletStore();
</script>

<template>
  <div>
    <div class="page-title"><h1>我的</h1><p>查看合约记录成本、当前税率和链上记录。</p></div>

    <div class="card">
      <div class="profile">
        <div class="profile-avatar">{{ wallet.isConnected ? 'ME' : '?' }}</div>
        <div><b>{{ wallet.isConnected ? wallet.shortAddress : '未连接钱包' }}</b><p>{{ wallet.isConnected ? 'BSC Testnet · Chain ID 97' : '连接后查看BSC Testnet资产' }}</p></div>
      </div>
      <div class="asset-main">{{ wallet.isConnected ? '126,840 PANGU2' : '— PANGU2' }}</div>
      <div class="asset-sub">{{ wallet.isConnected ? '约 $162.85' : '约 $—' }}</div>
      <div class="status-line">
        <span class="status-chip" :class="{ on: wallet.isConnected }">{{ wallet.isConnected ? '钱包已连接' : '钱包未连接' }}</span>
        <span class="status-chip" :class="{ on: wallet.isConnected }">{{ wallet.isConnected ? '前100名 · #36' : '排名未解锁' }}</span>
        <span class="status-chip">分红未领取</span>
      </div>
    </div>

    <div class="card" style="margin-top:11px">
      <div class="row"><span>合约记录成本</span><b>{{ wallet.isConnected ? '100.00 USDT' : '—' }}</b></div>
      <div class="row"><span>税前卖出参考价值</span><b>{{ wallet.isConnected ? '101.00 USDT' : '—' }}</b></div>
      <div class="row"><span>当前卖出协议税率</span><b class="tax-value">{{ wallet.isConnected ? '4%' : '—' }}</b></div>
    </div>

    <div class="card menu" style="margin-top:11px">
      <button><span class="menu-icon">◇</span><span>我的分红</span><span>›</span></button>
      <button><span class="menu-icon">⌁</span><span>托底池与锁仓</span><span>›</span></button>
      <button><span class="menu-icon">⌘</span><span>合约透明度</span><span>›</span></button>
      <button><span class="menu-icon">i</span><span>协议税费规则</span><span>›</span></button>
      <button v-if="wallet.isConnected" @click="wallet.disconnect()"><span class="menu-icon">↪</span><span>断开钱包</span><span>›</span></button>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }
.profile { display: flex; align-items: center; gap: 10px; }
.profile-avatar { width: 42px; height: 42px; border-radius: 14px; background: rgba(216,170,81,.1); color: var(--gold2); display: grid; place-items: center; font-weight: 950; }
.profile b { font-size: 12px; }
.profile p { margin-top: 4px; color: var(--muted); font-size: 9px; }
.asset-main { font-size: 27px; font-weight: 950; margin-top: 17px; }
.asset-sub { font-size: 10px; color: var(--muted); margin-top: 4px; }
.status-line { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 12px; }
.status-chip { padding: 5px 7px; border-radius: 99px; font-size: 8px; color: var(--muted); border: 1px solid var(--line); }
.status-chip.on { color: var(--green); border-color: rgba(67,207,139,.22); background: rgba(67,207,139,.04); }
.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 9px 0; font-size: 11px; }
.row+.row { border-top: 1px solid rgba(255,255,255,.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.tax-value { font-size: 18px !important; color: var(--gold2); }
.menu button { width: 100%; display: grid; grid-template-columns: 30px 1fr auto; align-items: center; text-align: left; border: 0; background: none; padding: 12px 0; }
.menu button+button { border-top: 1px solid rgba(255,255,255,.05); }
.menu-icon { width: 26px; height: 26px; border-radius: 9px; background: #20242c; display: grid; place-items: center; color: var(--gold2); }
.menu button>span:nth-child(2) { font-size: 11px; }
.menu button>span:last-child { color: var(--muted); }
</style>
