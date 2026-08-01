<script setup lang="ts">
import { useWalletStore } from "@/stores/useWallet";
const wallet = useWalletStore();
</script>

<template>
  <div>
    <div class="hero">
      <div class="live"><i class="dot"></i><span>链上数据已同步 · 区块 42,814,982</span></div>
      <div class="price-label">PANGU2 参考价</div>
      <div class="price">$0.001284</div>
      <div class="change">+3.18% · 24H</div>
      <div class="hero-actions">
        <button class="primary-btn" @click="$router.push('/trade?mode=buy')">买入</button>
        <button class="secondary-btn" @click="$router.push('/trade?mode=sell')">卖出</button>
      </div>
    </div>

    <div class="card">
      <div class="card-title-row">
        <h3>{{ wallet.isConnected ? '你的链上位置' : '连接钱包查看个人数据' }}</h3>
        <span class="tag">公开可验证</span>
      </div>
      <p class="sub">{{ wallet.isConnected ? '当前排名#36，本周期有可领取分红。' : '余额、排名、分红和当前协议税率均从合约读取。' }}</p>
      <div class="wallet-grid">
        <div class="metric"><small>我的持仓</small><b>{{ wallet.isConnected ? '126,840' : '—' }}</b><em>{{ wallet.isConnected ? '约 $162.85' : '约 $—' }}</em></div>
        <div class="metric"><small>当前排名</small><b>{{ wallet.isConnected ? '#36' : '—' }}</b><em>前100名分红</em></div>
        <div class="metric"><small>可领取</small><b>{{ wallet.isConnected ? '2,846' : '—' }}</b><em>PANGU2</em></div>
      </div>
      <button class="full-btn" style="margin-top:13px" @click="wallet.isConnected ? undefined : wallet.openConnectSheet()">
        {{ wallet.isConnected ? '查看我的资产' : '连接钱包' }}
      </button>
    </div>

    <div class="section-head"><h2>当前协议规则</h2></div>
    <div class="rule-grid">
      <div class="rule"><b>4%</b><span>买入税<br>前100名分红</span></div>
      <div class="rule"><b>{{ wallet.isConnected ? '4%' : '—' }}</b><span>当前卖出税<br>合约实时返回</span></div>
      <div class="rule"><b>0.01</b><span>BNB / 次<br>回购后锁仓</span></div>
    </div>

    <div class="section-head"><h2>托底池</h2></div>
    <div class="card">
      <div class="pool-pulse">
        <div><div class="sub">下一次允许回购</div><div class="countdown">00:37</div></div>
        <div class="pool-right"><b>18.42 BNB</b><span>可执行约1,842次</span></div>
      </div>
      <div class="progress"><i style="width:38%"></i></div>
      <p class="sub" style="margin-top:10px">税费代币达到门槛后兑换为BNB，再按每次0.01 BNB执行回购。</p>
    </div>
  </div>
</template>

<style scoped>
.live { display: flex; align-items: center; gap: 7px; font-size: 10px; color: var(--muted); }
.price-label { font-size: 10px; color: var(--muted); margin-top: 17px; }
.price { font-size: 36px; line-height: 1.1; font-weight: 950; letter-spacing: -1.3px; margin-top: 4px; }
.change { font-size: 10px; color: var(--green); font-weight: 850; margin-top: 5px; }
.hero-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 9px; margin-top: 16px; }
.card-title-row { display: flex; align-items: center; justify-content: space-between; }
.card-title-row h3 { font-size: 14px; margin: 0; }
.wallet-grid { display: grid; grid-template-columns: 1.25fr .8fr .9fr; gap: 8px; margin-top: 12px; }
.metric small { display: block; color: var(--muted); font-size: 9px; }
.metric b { display: block; font-size: 15px; margin-top: 5px; }
.metric em { display: block; font-style: normal; color: var(--muted); font-size: 8px; margin-top: 3px; }
.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }
.rule-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 7px; }
.rule { padding: 11px 5px; border-radius: 13px; text-align: center; background: rgba(255,255,255,.025); border: 1px solid rgba(255,255,255,.045); }
.rule b { display: block; color: var(--gold2); font-size: 16px; }
.rule span { display: block; color: var(--muted); font-size: 8px; line-height: 1.4; margin-top: 4px; }
.pool-pulse { display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: center; }
.countdown { font-size: 27px; font-weight: 950; margin-top: 3px; }
.pool-right { text-align: right; }
.pool-right b { font-size: 13px; color: var(--gold2); }
.pool-right span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }
.progress { height: 6px; background: #252932; border-radius: 99px; overflow: hidden; margin-top: 10px; }
.progress i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), var(--gold2)); border-radius: inherit; transition: .3s; }
</style>
