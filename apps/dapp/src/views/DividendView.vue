<script setup lang="ts">
import { useWalletStore } from "@/stores/useWallet";
const wallet = useWalletStore();
</script>

<template>
  <div>
    <div class="page-title"><h1>前100名分红</h1><p>买入税4%进入分红池，排名按公开快照计算。</p></div>

    <div class="card rank-card">
      <div class="rank-top">
        <div class="rank-number"><small>我的排名</small><b>{{ wallet.isConnected ? '#36' : '—' }}</b></div>
        <div class="claim-box"><small>本周期可领取</small><b>{{ wallet.isConnected ? '2,846 P2' : '—' }}</b></div>
      </div>
      <div class="rank-goal">
        <div class="rank-goal-top"><b>{{ wallet.isConnected ? '距离前30名还差18,160 P2' : '连接钱包查看排名' }}</b><span>{{ wallet.isConnected ? '72%' : '—' }}</span></div>
        <div class="progress"><i :style="{ width: wallet.isConnected ? '72%' : '5%' }"></i></div>
        <div class="rank-labels"><span>#100</span><span>#60</span><span>#30</span><span>#10</span></div>
      </div>
      <button class="full-btn" style="margin-top:14px" @click="wallet.isConnected ? undefined : wallet.openConnectSheet()">
        {{ wallet.isConnected ? '领取 2,846 PANGU2' : '连接钱包' }}
      </button>
    </div>

    <div class="section-head"><h2>分红档位</h2></div>
    <div class="tiers">
      <div class="tier"><b>35%</b><span>第1–10名</span></div>
      <div class="tier"><b>25%</b><span>第11–30名</span></div>
      <div class="tier active"><b>25%</b><span>第31–60名</span></div>
      <div class="tier"><b>15%</b><span>第61–100名</span></div>
    </div>

    <div class="section-head"><h2>当前排名</h2></div>
    <div class="card">
      <div class="leader"><div class="place">01</div><div class="avatar">7A</div><div class="leader-info"><b>0x7A91...F2B8</b><span>21,820,000 PANGU2</span></div><div class="leader-value"><b>8.42%</b><span>权重</span></div></div>
      <div class="leader"><div class="place">02</div><div class="avatar">42</div><div class="leader-info"><b>0x42DE...71AC</b><span>18,440,000 PANGU2</span></div><div class="leader-value"><b>7.11%</b><span>权重</span></div></div>
      <div class="leader my-row" v-if="wallet.isConnected">
        <div class="place">36</div><div class="avatar">ME</div><div class="leader-info"><b>{{ wallet.shortAddress }}</b><span>126,840 PANGU2 · 距#30差18,160</span></div><div class="leader-value"><b>0.18%</b><span>权重</span></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }
.rank-card { text-align: center; padding: 18px; }
.rank-top { display: flex; justify-content: space-between; align-items: flex-start; text-align: left; }
.rank-number small, .claim-box small { display: block; color: var(--muted); font-size: 9px; }
.rank-number b { display: block; color: var(--gold2); font-size: 31px; margin-top: 3px; }
.claim-box { text-align: right; }
.claim-box b { display: block; font-size: 17px; margin-top: 5px; }
.rank-goal { margin-top: 14px; text-align: left; }
.rank-goal-top { display: flex; justify-content: space-between; color: var(--muted); font-size: 9px; }
.rank-goal-top b { font-size: 10px; color: var(--text); }
.rank-labels { display: flex; justify-content: space-between; color: #676d79; font-size: 8px; margin-top: 5px; }
.progress { height: 6px; background: #252932; border-radius: 99px; overflow: hidden; margin-top: 10px; }
.progress i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), var(--gold2)); border-radius: inherit; transition: .3s; }
.tiers { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; }
.tier { padding: 10px 4px; border-radius: 12px; border: 1px solid var(--line); text-align: center; }
.tier.active { border-color: rgba(216,170,81,.4); background: rgba(216,170,81,.06); }
.tier b { display: block; font-size: 13px; color: var(--gold2); }
.tier span { font-size: 8px; color: var(--muted); }
.leader { display: flex; align-items: center; gap: 9px; padding: 9px 0; }
.leader+.leader { border-top: 1px solid rgba(255,255,255,.05); }
.place { width: 24px; color: var(--muted); font-size: 9px; }
.avatar { width: 30px; height: 30px; border-radius: 10px; background: #222730; display: grid; place-items: center; font-size: 8px; }
.leader-info { flex: 1; min-width: 0; }
.leader-info b { display: block; font-size: 9px; }
.leader-info span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }
.leader-value { text-align: right; }
.leader-value b { font-size: 9px; }
.leader-value span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }
.my-row { background: rgba(216,170,81,.045); margin: 0 -8px; padding: 9px 8px; border-radius: 12px; }
.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }
</style>
