<script setup lang="ts">
import { ref } from "vue";
const mode = ref<"buy" | "sell">("buy");
const payAmount = ref("0.10");

function toggleMode(m: "buy" | "sell") { mode.value = m; payAmount.value = m === "buy" ? "0.10" : "10000"; }
</script>

<template>
  <div>
    <div class="page-title"><h1>交易</h1><p>交易前由合约返回当前税率和最低预计到账。</p></div>
    <div class="seg">
      <button :class="{ active: mode === 'buy' }" @click="toggleMode('buy')">买入</button>
      <button :class="{ active: mode === 'sell' }" @click="toggleMode('sell')">卖出</button>
    </div>

    <div class="input-card">
      <div class="input-top"><span>支付</span><span>{{ mode === 'buy' ? '余额 3.284 BNB' : '余额 126,840 PANGU2' }}</span></div>
      <div class="input-row">
        <input v-model="payAmount" inputmode="decimal">
        <button class="max-btn">MAX</button>
        <div class="token"><i class="coin">{{ mode === 'buy' ? 'B' : 'P' }}</i><span>{{ mode === 'buy' ? 'BNB' : 'PANGU2' }}</span></div>
      </div>
    </div>

    <div class="swap-arrow">↓</div>

    <div class="input-card">
      <div class="input-top"><span>预计获得</span><span>报价已更新</span></div>
      <div class="input-row">
        <input readonly :value="mode === 'buy' ? '44,385.6' : '0.021400'">
        <div class="token"><i class="coin">{{ mode === 'buy' ? 'P' : 'B' }}</i><span>{{ mode === 'buy' ? 'PANGU2' : 'BNB' }}</span></div>
      </div>
    </div>

    <div class="card quote-card">
      <div class="row"><span>当前协议税率</span><b class="tax-value">{{ mode === 'buy' ? '4.00%' : '4.00%' }}</b></div>
      <div class="row"><span>税费数量</span><b>{{ mode === 'buy' ? '1,849.4 P2' : '400 P2' }}</b></div>
      <div class="row"><span>资金去向</span><b>{{ mode === 'buy' ? '前100名分红池' : '托底池' }}</b></div>
      <div class="row"><span>最低预计到账</span><b>{{ mode === 'buy' ? '43,941 P2' : '0.0211 BNB' }}</b></div>
      <div class="row"><span>预计 Gas</span><b>≈ 0.00021 BNB</b></div>
      <div class="quote-note">
        <i>✓</i>
        <div><b>合约报价检查通过</b><span>买入税4%，税后数量已计入报价。</span></div>
      </div>
      <div class="quote-source">原型模拟：正式版通过 previewBuy / previewSell 读取链上结果</div>
    </div>

    <button class="full-btn" style="margin-top:12px">{{ mode === 'buy' ? '确认买入' : '授权并卖出' }}</button>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); line-height: 1.5; margin-top: 6px; }
.seg { display: grid; grid-template-columns: 1fr 1fr; padding: 4px; border: 1px solid var(--line); border-radius: 14px; background: var(--panel); margin-bottom: 10px; }
.seg button { height: 39px; border: 0; border-radius: 10px; background: none; color: var(--muted); font-weight: 850; }
.seg button.active { background: #252a33; color: var(--text); }
.input-card { padding: 13px; border-radius: 16px; border: 1px solid var(--line); background: var(--panel); }
.input-card+.input-card { margin-top: 8px; }
.input-top { display: flex; justify-content: space-between; color: var(--muted); font-size: 9px; }
.input-row { display: flex; gap: 9px; align-items: center; margin-top: 11px; }
.input-row input { flex: 1; min-width: 0; border: 0; outline: 0; background: none; color: var(--text); font-size: 27px; font-weight: 900; }
.max-btn { border: 0; background: none; color: var(--gold); font-size: 9px; }
.token { display: flex; align-items: center; gap: 6px; padding: 7px 9px; border-radius: 11px; background: #222730; font-size: 11px; font-weight: 850; }
.coin { width: 21px; height: 21px; border-radius: 50%; display: grid; place-items: center; background: var(--gold); color: #171108; font-size: 9px; }
.swap-arrow { width: 34px; height: 34px; margin: -4px auto; border: 4px solid var(--bg); border-radius: 11px; background: #222730; display: grid; place-items: center; position: relative; z-index: 2; }
.quote-card { margin-top: 10px; }
.row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 9px 0; font-size: 11px; }
.row+.row { border-top: 1px solid rgba(255,255,255,.04); }
.row span { color: var(--muted); }
.row b { text-align: right; }
.tax-value { font-size: 18px !important; color: var(--gold2); }
.quote-note { display: flex; gap: 10px; align-items: center; padding: 11px; border-radius: 13px; background: rgba(216,170,81,.055); border: 1px solid rgba(216,170,81,.13); margin-top: 10px; }
.quote-note i { width: 31px; height: 31px; border-radius: 10px; display: grid; place-items: center; background: rgba(216,170,81,.1); font-style: normal; }
.quote-note b { font-size: 10px; }
.quote-note span { display: block; color: var(--muted); font-size: 9px; line-height: 1.4; margin-top: 3px; }
.quote-source { font-size: 8px; color: #676d79; text-align: center; padding-top: 8px; }
</style>
