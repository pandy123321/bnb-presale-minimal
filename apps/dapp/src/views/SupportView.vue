<script setup lang="ts">
</script>

<template>
  <div>
    <div class="page-title"><h1>托底池</h1><p>卖出税费先累计为PANGU2，达到门槛后兑换为BNB，再分批回购并锁仓。</p></div>

    <div class="detail-grid">
      <div class="detail-stat"><span>待兑换税费</span><b>2.84M P2</b></div>
      <div class="detail-stat"><span>托底池余额</span><b>18.42 BNB</b></div>
      <div class="detail-stat"><span>累计回购</span><b>42.8M P2</b></div>
      <div class="detail-stat"><span>累计销毁</span><b>8.21M P2</b></div>
    </div>

    <div class="section-head"><h2>资金流程</h2></div>
    <div class="card">
      <div class="flow">
        <div class="flow-box">卖出税费 P2</div><div class="flow-arrow">→</div>
        <div class="flow-box">兑换 BNB</div><div class="flow-arrow">→</div>
        <div class="flow-box">0.01 BNB 回购</div><div class="flow-arrow">→</div>
        <div class="flow-box">锁仓365天</div>
      </div>
    </div>

    <div class="section-head"><h2>下一次可执行</h2></div>
    <div class="card">
      <div class="pool-pulse">
        <div><div class="sub">最小间隔60秒</div><div class="countdown">00:37</div></div>
        <div class="pool-right"><b>0.01 BNB</b><span>约回购4,607 P2</span></div>
      </div>
      <div class="progress"><i style="width:38%"></i></div>
      <button class="full-btn" style="margin-top:13px">公开触发回购</button>
    </div>

    <div class="section-head"><h2>最近回购</h2></div>
    <div class="card">
      <div class="timeline-item"><div class="timeline-dot">✓</div><div class="timeline-copy"><b>回购4,612 PANGU2</b><span>0.01 BNB · 锁仓批次#1247 · 2分钟前</span></div></div>
      <div class="timeline-item"><div class="timeline-dot">✓</div><div class="timeline-copy"><b>回购4,598 PANGU2</b><span>0.01 BNB · 锁仓批次#1246 · 3分钟前</span></div></div>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }
.detail-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.detail-stat { padding: 11px; border-radius: 13px; border: 1px solid rgba(255,255,255,.045); background: rgba(255,255,255,.025); }
.detail-stat span { display: block; color: var(--muted); font-size: 8px; }
.detail-stat b { display: block; margin-top: 5px; font-size: 13px; }
.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }
.flow { display: flex; align-items: center; gap: 7px; overflow-x: auto; padding: 4px 0; }
.flow-box { flex: 0 0 auto; padding: 9px 10px; border-radius: 12px; border: 1px solid var(--line); background: var(--panel2); font-size: 9px; }
.flow-arrow { color: var(--gold); }
.pool-pulse { display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: center; }
.countdown { font-size: 27px; font-weight: 950; margin-top: 3px; }
.pool-right { text-align: right; }
.pool-right b { font-size: 13px; color: var(--gold2); }
.pool-right span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }
.progress { height: 6px; background: #252932; border-radius: 99px; overflow: hidden; margin-top: 10px; }
.progress i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), var(--gold2)); border-radius: inherit; transition: .3s; }
.timeline-item { display: flex; gap: 10px; padding: 10px 0; }
.timeline-item+.timeline-item { border-top: 1px solid rgba(255,255,255,.05); }
.timeline-dot { width: 30px; height: 30px; border-radius: 10px; background: rgba(67,207,139,.08); color: var(--green); display: grid; place-items: center; }
.timeline-copy b { display: block; font-size: 10px; }
.timeline-copy span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }
</style>
