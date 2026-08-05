<script setup lang="ts">
import { ref, computed } from "vue";
import Card from "@ui/components/Card.vue";
import Tag from "@ui/components/Tag.vue";
import SectionHead from "@ui/components/SectionHead.vue";

const mode = ref<"buy" | "sell">("buy");
const payAmount = ref("0.25");

const activityFilter = ref<"all" | "buy" | "sell">("all");

const activities = [
  { type: "buy" as const, amount: "12,840 BGP", bnb: "0.028 BNB", time: "2m ago", status: "confirmed" },
  { type: "sell" as const, amount: "5,200 BGP", bnb: "0.012 BNB", time: "8m ago", status: "confirmed" },
  { type: "buy" as const, amount: "31,600 BGP", bnb: "0.068 BNB", time: "14m ago", status: "confirmed" },
  { type: "buy" as const, amount: "8,100 BGP", bnb: "0.018 BNB", time: "22m ago", status: "confirmed" },
  { type: "sell" as const, amount: "2,850 BGP", bnb: "0.006 BNB", time: "31m ago", status: "confirmed" },
];

const filteredActivities = computed(() => activityFilter.value === "all" ? activities : activities.filter(a => a.type === activityFilter.value));

function toggleMode(m: "buy" | "sell") { mode.value = m; }

const demoPrice = "0.00000284";
const demoChange = "+4.72%";
</script>

<template>
  <div class="page-trade">
    <div class="page-title"><h1>Trade</h1><p>Contract real-time quote. Tax rate determined by on-chain contract.</p></div>

    <!-- ═══ 1. Market Card ═══ -->
    <Card>
      <div class="market-head">
        <div class="pair">BGP / BNB<small><Tag variant="demo">Preview data</Tag></small></div>
        <div class="price"><b>{{ demoPrice }} BNB</b><span class="green">{{ demoChange }}</span></div>
      </div>
      <div class="market-toolbar">
        <div class="timeframes">
          <button>1H</button><button class="active">1D</button><button>1W</button><button>1M</button>
        </div>
        <span class="market-status"><i></i><span>Preview data</span></span>
      </div>
      <!-- Chart placeholder: trading NOT yet activated -->
      <div class="chart-placeholder">
        <b>Trading not yet activated</b>
        <small>The administrator will enable trading after oracle finalization.</small>
        <small class="muted">No countdown. Check back later.</small>
      </div>
      <div class="market-grid">
        <div class="market-stat"><span>24h volume</span><b>128 BNB</b></div>
        <div class="market-stat"><span>Liquidity</span><b>420 BNB</b></div>
        <div class="market-stat"><span>Holders</span><b>6.8K</b></div>
      </div>
      <div class="market-detail-strip">
        <div class="market-detail"><span>24h high</span><b>0.00000291</b></div>
        <div class="market-detail"><span>24h low</span><b>0.00000256</b></div>
        <div class="market-detail"><span>Pool depth</span><b>420 BNB</b></div>
        <div class="market-detail"><span>Market status</span><b class="green">Preview</b></div>
      </div>
    </Card>

    <!-- ═══ 2. Order Panel ═══ -->
    <Card style="margin-top:12px">
      <div class="trade-context"><span>BGP / BNB</span><b>BNB Smart Chain</b></div>
      <div class="segmented">
        <button :class="{ active: mode === 'buy' }" @click="toggleMode('buy')">Buy</button>
        <button :class="{ active: mode === 'sell' }" @click="toggleMode('sell')">Sell</button>
      </div>
      <div class="trade-box">
        <div class="trade-meta"><span>You pay</span><span>Balance 2.48 BNB</span></div>
        <div class="trade-input"><input v-model="payAmount" inputmode="decimal"><button class="max-btn">MAX</button><span class="token">BNB</span></div>
        <div class="quick"><button>25%</button><button>50%</button><button>75%</button><button>MAX</button></div>
      </div>
      <div class="swap-arrow">↓</div>
      <div class="trade-box">
        <div class="trade-meta"><span>You receive</span><Tag variant="demo">Preview data</Tag></div>
        <div class="trade-input"><input readonly :value="'88,046'"><span class="token">BGP</span></div>
      </div>
      <div class="detail-list">
        <div class="detail-row"><span>Protocol fee</span><b>4%</b></div>
        <div class="detail-row"><span>Minimum received</span><b>87,165 BGP</b></div>
        <div class="detail-row"><span>Price impact</span><b>0.12%</b></div>
        <div class="detail-row"><span>Route</span><b>BNB → BGP</b></div>
      </div>
      <div class="trade-footer-row">
        <div><span>Gas estimate</span><b>0.00021 BNB</b></div>
        <div><span>Pool depth</span><b>420 BNB</b></div>
      </div>
      <button class="btn primary" style="width:100%;margin-top:12px" disabled>Trading not yet activated</button>
    </Card>

    <!-- ═══ 3. Activity ═══ -->
    <div class="section">
      <SectionHead title="Recent activity">
        <template #actions>
          <div class="activity-tabs">
            <button :class="{ active: activityFilter === 'all' }" @click="activityFilter='all'">All</button>
            <button :class="{ active: activityFilter === 'buy' }" @click="activityFilter='buy'">Buys</button>
            <button :class="{ active: activityFilter === 'sell' }" @click="activityFilter='sell'">Sells</button>
          </div>
        </template>
      </SectionHead>
      <div class="activity-list">
        <div v-for="(a, i) in filteredActivities" :key="i" class="activity-row">
          <span class="activity-type" :class="a.type">{{ a.type === 'buy' ? 'Buy' : 'Sell' }}</span>
          <div class="activity-info"><b>{{ a.amount }}</b><small>{{ a.bnb }} · {{ a.time }}</small></div>
          <span class="activity-status">{{ a.status }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ── Market ── */
.market-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.pair { font-size: 13px; font-weight: 800; }
.pair small { display: block; margin-top: 4px; }
.price { text-align: right; }
.price b { display: block; font-size: 18px; }
.price span { display: block; font-size: 11px; margin-top: 4px; }
.market-toolbar { display: flex; justify-content: space-between; align-items: center; margin-top: 14px; }
.timeframes { display: flex; gap: 4px; }
.timeframes button { height: 28px; padding: 0 10px; border-radius: 8px; border: 1px solid var(--line); background: transparent; color: var(--text-3); font-size: 10px; cursor: pointer; }
.timeframes button.active { background: rgba(76,201,240,.08); border-color: rgba(76,201,240,.28); color: var(--cyan); }
.market-status { display: flex; align-items: center; gap: 5px; font-size: 9px; color: var(--text-3); }
.market-status i { width: 6px; height: 6px; border-radius: 50%; background: var(--green); }

/* Chart placeholder (trading not activated) */
.chart-placeholder { height: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; margin: 16px 0; border-radius: 14px; background: rgba(13,20,34,.78); border: 1px solid rgba(255,255,255,.04); }
.chart-placeholder b { font-size: 14px; color: var(--text-2); }
.chart-placeholder small { font-size: 10px; color: var(--text-3); max-width: 280px; text-align: center; line-height: 1.5; }

.market-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-top: 14px; }
.market-stat { padding: 10px; border-radius: 12px; background: rgba(255,255,255,.02); }
.market-stat span { display: block; font-size: 8px; color: var(--text-3); }
.market-stat b { display: block; font-size: 12px; margin-top: 5px; }
.market-detail-strip { display: grid; grid-template-columns: repeat(2, 1fr); gap: 6px; margin-top: 12px; }
.market-detail { padding: 8px 10px; border-radius: 10px; background: rgba(255,255,255,.015); display: flex; justify-content: space-between; align-items: center; }
.market-detail span { font-size: 8px; color: var(--text-3); }
.market-detail b { font-size: 11px; }

/* ── Order Panel ── */
.trade-context { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; padding: 8px 10px; border-radius: 10px; background: rgba(255,255,255,.02); }
.trade-context span { font-size: 10px; color: var(--text-2); }
.trade-context b { font-size: 9px; color: var(--text-3); }
.segmented { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 12px; }
.segmented button { height: 40px; border-radius: 12px; border: 1px solid var(--line); background: transparent; color: var(--text-3); font-size: 13px; font-weight: 800; cursor: pointer; }
.segmented button.active { background: rgba(76,201,240,.08); border-color: rgba(76,201,240,.28); color: #E9FAFF; }
.trade-box { padding: 14px; border-radius: 14px; background: rgba(255,255,255,.02); }
.trade-meta { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.trade-meta span { font-size: 9px; color: var(--text-3); }
.trade-input { display: flex; align-items: center; gap: 8px; }
.trade-input input { min-width: 0; width: 100%; border: 0; outline: 0; background: transparent; color: var(--text); font-size: 24px; font-weight: 850; }
.max-btn { height: 28px; padding: 0 10px; border-radius: 8px; border: 1px solid var(--cyan); background: transparent; color: var(--cyan); font-size: 10px; font-weight: 800; cursor: pointer; flex-shrink: 0; }
.token { font-size: 12px; color: var(--text-2); font-weight: 800; flex-shrink: 0; }
.quick { display: grid; grid-template-columns: repeat(4, 1fr); gap: 5px; margin-top: 10px; }
.quick button { height: 30px; border-radius: 8px; border: 1px solid var(--line); background: transparent; color: var(--text-3); font-size: 9px; font-weight: 700; cursor: pointer; }
.swap-arrow { text-align: center; font-size: 18px; color: var(--text-3); margin: 8px 0; }
.trade-footer-row { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 12px; }
.trade-footer-row div { padding: 8px 10px; border-radius: 10px; background: rgba(255,255,255,.015); }
.trade-footer-row span { display: block; font-size: 8px; color: var(--text-3); }
.trade-footer-row b { display: block; font-size: 10px; margin-top: 4px; }

/* ── Activity ── */
.activity-tabs { display: flex; gap: 4px; }
.activity-tabs button { height: 24px; padding: 0 8px; border-radius: 6px; border: 1px solid var(--line); background: transparent; color: var(--text-3); font-size: 9px; cursor: pointer; }
.activity-tabs button.active { background: rgba(76,201,240,.08); border-color: rgba(76,201,240,.25); color: var(--cyan); }
.activity-list { margin-top: 4px; }
.activity-row { display: grid; grid-template-columns: 48px 1fr auto; gap: 10px; align-items: center; padding: 12px 0; border-top: 1px solid rgba(255,255,255,.045); }
.activity-row:first-child { border-top: 0; }
.activity-type { width: 48px; height: 24px; border-radius: 8px; display: grid; place-items: center; font-size: 9px; font-weight: 800; }
.activity-type.buy { color: var(--green); background: rgba(57,201,155,.08); }
.activity-type.sell { color: var(--red); background: rgba(255,113,129,.08); }
.activity-info b { display: block; font-size: 11px; }
.activity-info small { display: block; font-size: 8px; color: var(--text-3); margin-top: 3px; }
.activity-status { font-size: 9px; color: var(--green); }
</style>
