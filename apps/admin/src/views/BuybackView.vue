<script setup lang="ts">
// Buyback data is read from real API — displays syncing placeholder until chain worker confirms events.
const noData = "\u2014";
</script>

<template>
  <div>
    <div class="hero">
      <div><h3>Buyback &amp; Locker</h3><p>Support fee tokens are converted to BNB, then used for 0.01 BNB buybacks locked for 365 days.</p></div>
      <div class="hero-side"><strong>Syncing</strong><small>Waiting for chain worker</small></div>
    </div>

    <div class="kpi-grid">
      <div class="kpi"><div class="kpi-head"><span>Pending Fee Tokens</span></div><strong>{{ noData }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>Support Pool BNB</span></div><strong>{{ noData }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>Total Buybacks</span></div><strong>{{ noData }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>Total Burned</span></div><strong>{{ noData }}</strong></div>
    </div>

    <div class="section-head"><h3>Buyback Conditions</h3></div>
    <div class="layout-even">
      <div class="card">
        <div class="card-head"><h4>Preconditions</h4><span class="tag muted">Pending sync</span></div>
        <div class="card-body">
          <div class="check"><span>SupportPool BNB &ge; 0.01</span><span class="tag muted">{{ noData }}</span></div>
          <div class="check"><span>Since last buyback &ge; 60s</span><span class="tag muted">{{ noData }}</span></div>
          <div class="check"><span>Contract not paused</span><span class="tag muted">{{ noData }}</span></div>
        </div>
      </div>
      <div class="card">
        <div class="card-head"><h4>Next Buyback Preview</h4><span class="tag muted">Pending</span></div>
        <div class="card-body">
          <div class="metric-row"><span>Amount</span><b>0.01 BNB</b></div>
          <div class="metric-row"><span>Estimated tokens</span><b>{{ noData }}</b></div>
          <div class="metric-row"><span>Recipient</span><b class="mono">BuybackLocker</b></div>
          <div class="metric-row"><span>Lock duration</span><b>365 days</b></div>
        </div>
      </div>
    </div>

    <div class="section-head"><h3>Buyback Batches</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="table">
          <div class="tr head"><span>Batch</span><span>BNB</span><span>Tokens</span><span>Time</span></div>
        </div>
        <div class="empty-state">
          <b>No buyback batches yet</b>
          <small>Data will appear once the chain worker confirms on-chain buyback events.</small>
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
.empty-state { padding: 24px; text-align: center; }
.empty-state b { display: block; color: var(--muted); }
.empty-state small { display: block; color: var(--muted); margin-top: 6px; font-size: 11px; }
@media (max-width: 1180px) { .kpi-grid { grid-template-columns: repeat(2, 1fr); } }
</style>
