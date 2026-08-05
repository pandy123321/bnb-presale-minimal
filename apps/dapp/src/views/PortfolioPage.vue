<script setup lang="ts">
import { computed } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import Card from "@ui/components/Card.vue";
import Button from "@ui/components/Button.vue";
import Tag from "@ui/components/Tag.vue";
import SectionHead from "@ui/components/SectionHead.vue";

const wallet = useWalletStore();
const hasWallet = computed(() => wallet.isConnected);

const shortAddr = computed(() => hasWallet.value ? `${wallet.address?.slice(0,6)}…${wallet.address?.slice(-4)}` : "Connect to view");

// ── Preview distribution (unified data source for Donut + Legend) ──
const dist = [
  { name: "Locked", amount: 620, color: "var(--cyan)", cls: "legend-cyan" },
  { name: "Available", amount: 248, color: "var(--gold)", cls: "legend-gold" },
  { name: "Rewards", amount: 38, color: "var(--violet)", cls: "legend-violet" },
];
const distTotal = dist.reduce((s, d) => s + d.amount, 0);
const distPct = (n: number) => Math.round((n / distTotal) * 100);
const distConic = () => {
  let acc = 0; return dist.map(d => { const start = acc; acc += d.amount; return `${d.color} ${(start / distTotal) * 360}deg ${(acc / distTotal) * 360}deg`; }).join(", ");
};

const referralData: { addr: string; label: string; amount: string; lockAmt: string; locked: boolean }[] = [
  { addr: "0xA812…7C19", label: "Direct member", amount: "62W BGP", lockAmt: "40W", locked: true },
  { addr: "0xC21F…90B4", label: "Direct member", amount: "48W BGP", lockAmt: "20W", locked: true },
  { addr: "0x9F73…13D8", label: "Direct member", amount: "31W BGP", lockAmt: "0W", locked: false },
  { addr: "0x541B…0A22", label: "Direct member", amount: "24W BGP", lockAmt: "12W", locked: true },
];

const buybackBatches = [
  { id: 24, amount: "314K PANGU2", lockedUntil: "2027-08-01", status: "Locked" },
  { id: 23, amount: "312K PANGU2", lockedUntil: "2027-07-25", status: "Locked" },
  { id: 22, amount: "310K PANGU2", lockedUntil: "2027-07-18", status: "Locked" },
];

const fmtDate = (s: string) => new Date(s).toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
</script>

<template>
  <div class="page-portfolio">
    <div class="page-title"><h1>Portfolio</h1><p>Asset overview, staking, and team referrals.</p></div>
    <Tag variant="demo" style="margin-bottom:12px">Preview data — all values shown are for demonstration</Tag>

    <!-- ═══ 1. Asset Overview ═══ -->
    <Card>
      <div class="portfolio-top">
        <div><h2>Wallet position</h2><small>{{ shortAddr }} · Demo</small></div>
        <Tag variant="demo">Preview</Tag>
      </div>
      <div class="asset-main-row">
        <div><b>{{ hasWallet ? "286W" : "—" }}</b><span>BGP balance</span></div>
        <div class="asset-right"><strong class="green">{{ hasWallet ? "+4.72%" : "—" }}</strong><span>{{ hasWallet ? "8.12 BNB" : "—" }}</span></div>
      </div>
      <div class="asset-stats-grid">
        <div><span>Locked</span><b>{{ hasWallet ? "620W" : "—" }}</b></div>
        <div><span>Available</span><b>{{ hasWallet ? "248W" : "—" }}</b></div>
        <div><span>Locked ratio</span><b>{{ hasWallet ? distPct(620) + "%" : "—" }}</b></div>
      </div>
    </Card>

    <!-- ═══ 2. DonutChart ═══ -->
    <div class="section">
      <SectionHead title="Asset distribution">
        <template #actions><Tag variant="demo">Preview</Tag></template>
      </SectionHead>
      <div class="donut-row">
        <div class="donut-visual" :style="{ background: `conic-gradient(${distConic()})` }">
          <div class="donut-hole"><b>{{ distTotal }}W</b><span>Total</span></div>
        </div>
        <div class="donut-legend">
          <div v-for="d in dist" :key="d.name" class="legend-item">
            <i :class="d.cls"></i><span>{{ d.name }}</span><b>{{ d.amount }}W</b><small>{{ distPct(d.amount) }}%</small>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══ 3. Staking ═══ -->
    <div class="section">
      <SectionHead title="Staking">
        <template #actions><button class="text-btn">Lock BGP</button></template>
      </SectionHead>
      <Card variant="soft">
        <div class="staking-grid">
          <div class="staking-metric"><span>Staked</span><b>{{ hasWallet ? "620W" : "—" }}</b></div>
          <div class="staking-metric"><span>Rewards</span><b class="gold">{{ hasWallet ? "284" : "—" }}</b></div>
          <div class="staking-metric"><span>APR</span><b>{{ hasWallet ? "12.4%" : "—" }}</b></div>
        </div>
        <Button variant="primary" class="stake-btn" disabled>Staking not yet available</Button>
      </Card>
    </div>

    <!-- ═══ 4. My Team ═══ -->
    <div class="section">
      <SectionHead title="My team">
        <template #actions><Tag variant="demo">Preview</Tag></template>
      </SectionHead>
      <div class="team-grid">
        <div class="team-stat team-stat-primary">
          <div class="team-visual" aria-hidden="true"><svg viewBox="0 0 140 72"><circle cx="70" cy="36" r="26" fill="none" stroke="rgba(76,201,240,.08)" stroke-width="1.5"/><circle cx="70" cy="18" r="6.5" fill="var(--gold)"/><circle cx="39" cy="30" r="5.5" fill="var(--cyan)"/><circle cx="101" cy="30" r="5.5" fill="var(--cyan)"/><circle cx="39" cy="53" r="5.5" fill="var(--cyan)"/><circle cx="70" cy="54" r="5.5" fill="var(--cyan)"/><circle cx="101" cy="53" r="5.5" fill="var(--cyan)"/></svg></div>
          <span>Team members</span><b>128</b>
        </div>
        <div class="team-stat"><span>Direct referrals</span><b>8</b></div>
        <div class="team-stat"><span>Team holdings</span><b>1280W</b></div>
      </div>
    </div>

    <!-- ═══ 5. Direct Referrals ═══ -->
    <div class="section">
      <SectionHead title="Direct referrals"><template #actions><span class="team-count">8</span></template></SectionHead>
      <div class="referral-list">
        <div v-for="(r, i) in referralData" :key="i" class="referral-row">
          <div><b>{{ r.addr }}</b><small>{{ r.label }}</small></div>
          <div class="referral-side"><strong>{{ r.amount }}</strong><Tag :variant="r.locked ? 'locked' : 'open'">{{ r.locked ? 'Locked' : 'Unlocked' }}&nbsp;{{ r.lockAmt }}</Tag></div>
        </div>
      </div>
    </div>

    <!-- ═══ 6. Share BGP ═══ -->
    <div class="section">
      <Card variant="soft">
        <div class="share-card"><div><b>Share BGP</b><small class="referral-code">Referral code&nbsp;BGP-8F3K2</small></div><Button variant="primary" class="share-btn">Share</Button></div>
      </Card>
    </div>

    <!-- ═══ 7. Buyback Batches ═══ -->
    <div class="section">
      <SectionHead title="Buyback batches"><template #actions><Tag variant="demo">Preview</Tag></template></SectionHead>
      <div class="batch-list">
        <div v-for="b in buybackBatches" :key="b.id" class="batch-row">
          <div><b>Batch #{{ b.id }}</b><small>{{ b.amount }} · Until {{ fmtDate(b.lockedUntil) }}</small></div>
          <Tag variant="locked">{{ b.status }}</Tag>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
/* ── Asset ── */
.portfolio-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.portfolio-top h2 { margin: 0; font-size: 13px; }
.portfolio-top small { display: block; font-size: 9px; color: var(--text-3); margin-top: 4px; }
.asset-main-row { display: flex; justify-content: space-between; align-items: flex-end; gap: 14px; margin-top: 17px; }
.asset-main-row b { font-size: 34px; letter-spacing: -.04em; }
.asset-main-row span { display: block; font-size: 9px; color: var(--text-3); margin-top: 5px; }
.asset-right { text-align: right; }
.asset-right strong { font-size: 13px; }
.asset-right span { display: block; font-size: 9px; color: var(--text-3); margin-top: 4px; }
.asset-stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-top: 14px; }
.asset-stats-grid div { padding: 10px; border-radius: 12px; background: rgba(255,255,255,.02); }
.asset-stats-grid span { display: block; font-size: 8px; color: var(--text-3); }
.asset-stats-grid b { display: block; font-size: 14px; margin-top: 4px; }

/* ── Donut ── */
.donut-row { display: flex; align-items: center; gap: 20px; }
.donut-visual { width: 120px; height: 120px; border-radius: 50%; display: grid; place-items: center; flex-shrink: 0; }
.donut-hole { width: 72px; height: 72px; border-radius: 50%; background: var(--bg); display: flex; flex-direction: column; align-items: center; justify-content: center; }
.donut-hole b { font-size: 14px; }
.donut-hole span { font-size: 8px; color: var(--text-3); }
.donut-legend { flex: 1; display: flex; flex-direction: column; gap: 10px; }
.legend-item { display: flex; align-items: center; gap: 9px; }
.legend-item i { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; }
.legend-cyan { background: var(--cyan); }
.legend-gold { background: var(--gold); }
.legend-violet { background: var(--violet); }
.legend-item span { font-size: 10px; color: var(--text-2); flex: 1; }
.legend-item b { font-size: 12px; }
.legend-item small { font-size: 9px; color: var(--text-3); margin-left: 6px; }

/* ── Staking ── */
.staking-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.staking-metric { text-align: center; }
.staking-metric span { display: block; font-size: 9px; color: var(--text-3); }
.staking-metric b { display: block; font-size: 20px; margin-top: 6px; }
.stake-btn { width: 100%; margin-top: 14px; }

/* ── Team ── */
.team-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.team-stat { padding: 14px; border-radius: 14px; background: rgba(255,255,255,.02); text-align: center; }
.team-stat-primary { grid-column: span 3; display: flex; align-items: center; gap: 14px; text-align: left; }
.team-visual { width: 70px; height: 70px; flex-shrink: 0; }
.team-visual svg { width: 100%; height: 100%; }
.team-stat span { display: block; font-size: 8px; color: var(--text-3); }
.team-stat b { display: block; font-size: 18px; margin-top: 6px; }
.team-count { font-size: 11px; font-weight: 800; color: var(--text-2); }

/* ── Referral ── */
.referral-list { padding: 5px 12px 4px; border-radius: 20px; background: rgba(12,17,29,.72); }
.referral-row { display: grid; grid-template-columns: 1fr auto; gap: 10px; align-items: center; padding: 12px 0; border-top: 1px solid rgba(255,255,255,.045); }
.referral-row:first-child { border-top: 0; }
.referral-row b { display: block; font-size: 11px; }
.referral-row small { display: block; font-size: 8px; color: var(--text-3); margin-top: 4px; }
.referral-side { text-align: right; }
.referral-side strong { display: block; font-size: 10px; }

/* ── Share ── */
.share-card { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.share-card b { display: block; font-size: 13px; }
.referral-code { display: block; font-size: 9px; color: var(--text-3); margin-top: 4px; }
.share-btn { min-height: 42px; }

/* ── Batches ── */
.batch-list { display: flex; flex-direction: column; gap: 6px; }
.batch-row { display: flex; justify-content: space-between; align-items: center; padding: 12px; border-radius: 14px; background: rgba(255,255,255,.02); }
.batch-row b { display: block; font-size: 11px; }
.batch-row small { display: block; font-size: 8px; color: var(--text-3); margin-top: 3px; }

.text-btn { border: 0; background: none; color: var(--text-3); font-size: 9px; font-weight: 800; cursor: pointer; }
</style>
