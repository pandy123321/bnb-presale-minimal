<script setup lang="ts">
</script>

<template>
  <div>
    <div class="hero">
      <div><h3>托底、回购与锁仓</h3><p>税费代币兑换为BNB后，固定0.01 BNB回购并锁仓。</p></div>
      <div class="hero-side"><strong>可执行</strong><small>canExecuteBuyback = true</small></div>
    </div>

    <div class="kpi-grid">
      <div class="kpi"><div class="kpi-head"><span>待兑换税费</span></div><strong>2,840,000 P2</strong></div>
      <div class="kpi"><div class="kpi-head"><span>托底池余额</span></div><strong>18.42 BNB</strong></div>
      <div class="kpi"><div class="kpi-head"><span>累计回购</span></div><strong>42,800,000 P2</strong></div>
      <div class="kpi"><div class="kpi-head"><span>累计销毁</span></div><strong>8,210,000 P2</strong></div>
    </div>

    <div class="section-head"><h3>回购条件检查</h3></div>
    <div class="layout-even">
      <div class="card">
        <div class="card-head"><h4>执行条件</h4><span class="tag ok">全部通过</span></div>
        <div class="card-body">
          <div class="check"><span>SupportPool BNB ≥ 0.01</span><span class="tag ok">通过</span></div>
          <div class="check"><span>距上次回购 ≥ 60秒</span><span class="tag ok">通过</span></div>
          <div class="check"><span>合约未暂停</span><span class="tag ok">通过</span></div>
        </div>
      </div>
      <div class="card">
        <div class="card-head"><h4>本次回购预览</h4><span class="tag gold">公开触发</span></div>
        <div class="card-body">
          <div class="metric-row"><span>回购金额</span><b>0.01 BNB</b></div>
          <div class="metric-row"><span>预计回购</span><b>4,607 P2</b></div>
          <div class="metric-row"><span>接收地址</span><b class="mono">Locker合约</b></div>
          <div class="metric-row"><span>锁仓期限</span><b>365天</b></div>
        </div>
      </div>
    </div>

    <div class="section-head"><h3>回购批次</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="table">
          <div class="tr head"><span>批次</span><span>BNB</span><span>Token</span><span>时间</span></div>
          <div class="tr"><span>#1247</span><span>0.01</span><span>4,612 P2</span><span>2分钟前</span></div>
          <div class="tr"><span>#1246</span><span>0.01</span><span>4,598 P2</span><span>3分钟前</span></div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.hero { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 20px; align-items: end; padding: 22px; border: 1px solid rgba(214,173,95,.22); background: linear-gradient(135deg, rgba(214,173,95,.11), rgba(17,19,24,.96) 48%, rgba(17,19,24,.78)); }
.hero h3 { font-size: 24px; margin: 0; font-weight: 740; }
.hero p { color: var(--muted); font-size: 12px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { color: var(--muted); font-size: 10px; }
.kpi-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-top: 12px; }
.kpi { border: 1px solid var(--line); background: var(--panel); padding: 16px; }
.kpi-head { color: var(--muted); font-size: 11px; }
.kpi strong { display: block; font-size: 23px; margin-top: 9px; font-weight: 720; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }
.check { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid rgba(255,255,255,.05); padding: 9px 0; font-size: 11px; }
.check:last-child { border-bottom: 0; }
.check span { color: var(--muted); }
.metric-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.metric-row:last-child { border-bottom: 0; }
.metric-row span { color: var(--muted); }
.table { min-width: 600px; overflow: auto; }
.tr { display: grid; grid-template-columns: repeat(4, minmax(100px, 1fr)); gap: 12px; align-items: center; min-height: 48px; padding: 8px 14px; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.tr.head { min-height: 38px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
@media (max-width: 1180px) { .kpi-grid { grid-template-columns: repeat(2, 1fr); } }
</style>
