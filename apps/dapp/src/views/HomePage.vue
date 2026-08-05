<script setup lang="ts">
import { computed } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import Card from "@ui/components/Card.vue";
import Tag from "@ui/components/Tag.vue";
import SectionHead from "@ui/components/SectionHead.vue";

const wallet = useWalletStore();

// ── Preview data (API integration pending; real data shows "—") ──
const noData = "—";

const rankData = [
  { no: "01", addr: "0x7A91…4E2C", label: "Top holder", amount: "842W BGP", lockLabel: "Locked", lockAmount: "620W", tagVariant: "locked" as const },
  { no: "02", addr: "0xB3F8…9D10", label: "Top holder", amount: "678W BGP", lockLabel: "Locked", lockAmount: "510W", tagVariant: "locked" as const },
  { no: "03", addr: "0x16C4…A82F", label: "Top holder", amount: "591W BGP", lockLabel: "Unlocked", lockAmount: "0W", tagVariant: "open" as const },
  { no: "04", addr: "0xD42A…7B55", label: "Top holder", amount: "463W BGP", lockLabel: "Locked", lockAmount: "300W", tagVariant: "locked" as const },
  { no: "05", addr: "0x90EE…31A7", label: "Top holder", amount: "388W BGP", lockLabel: "Unlocked", lockAmount: "0W", tagVariant: "open" as const },
];

const shortAddr = computed(() => wallet.isConnected ? `${wallet.address?.slice(0,6)}…${wallet.address?.slice(-4)}` : "Not connected");
</script>

<template>
  <div class="page-home">

    <!-- ═══ 1. Hero Banner ═══ -->
    <section class="hero">
      <div class="hero-topline">
        <div class="eyebrow">BGP · BingGoPlus</div>
        <span class="hero-network"><i></i><span>Preview data</span></span>
      </div>
      <div class="hero-copy">
        <h1>Precision meets transparency.</h1>
        <p>Trade with clarity. Participate in community rewards. Lock on your terms.</p>
        <div class="hero-market">
          <div><span>Price</span><b>{{ noData }} BNB <em class="green hero-change">{{ noData }}%</em></b></div>
          <div><span>Holders</span><b>{{ noData }}</b></div>
          <div><span>Liquidity</span><b>{{ noData }} BNB</b></div>
        </div>
        <div class="hero-actions">
          <router-link to="/trade" class="btn primary">Trade BGP</router-link>
          <router-link to="/portfolio" class="btn secondary">View portfolio</router-link>
        </div>
      </div>
      <div class="value-strip">
        <div class="value-chip"><i></i><b>Transparent by design</b><span>Visible rules. Verifiable execution.</span></div>
        <div class="value-chip"><i></i><b>Community aligned</b><span>Participation connects to rewards.</span></div>
        <div class="value-chip"><i></i><b>Flexible commitment</b><span>Choose the lock period that fits your view.</span></div>
      </div>
    </section>

    <!-- ═══ 2. Wallet Position ═══ -->
    <Card>
      <div class="wallet-top">
        <div>
          <h2>Wallet position</h2>
          <small>{{ shortAddr }}{{ wallet.isConnected ? '' : ' · Connect to view' }}</small>
        </div>
        <Tag variant="demo">Preview data</Tag>
      </div>
      <div class="wallet-chart-row">
        <div class="asset-main">
          <div>
            <b>{{ wallet.isConnected ? previewBalance : "—" }}</b>
            <span>BGP balance</span>
          </div>
          <div class="asset-change">
            <strong class="green">{{ wallet.isConnected ? `${previewChange}%` : "—" }}</strong>
            <span>{{ wallet.isConnected ? `${previewBnbValue} BNB` : "—" }}</span>
          </div>
        </div>
        <div class="mini-spark" aria-hidden="true" v-if="wallet.isConnected">
          <svg viewBox="0 0 112 54" xmlns="http://www.w3.org/2000/svg">
            <polyline fill="none" stroke="var(--cyan)" stroke-width="1.5" stroke-linecap="round"
              points="0,48 8,44 16,46 24,36 32,38 40,24 48,26 56,18 64,20 72,8 80,12 88,6 96,8 112,2"/>
            <polyline fill="none" stroke="var(--cyan)" stroke-width="0.5" stroke-linecap="round" opacity="0.3"
              points="0,52 8,48 16,50 24,42 32,44 40,30 48,32 56,24 64,26 72,14 80,18 88,12 96,14 112,8"/>
          </svg>
        </div>
      </div>
      <div class="asset-grid">
        <button class="asset-action"><span>Rewards</span><b>{{ wallet.isConnected ? '284' : "—" }}</b></button>
        <button class="asset-action"><span>Locked</span><b>{{ wallet.isConnected ? '620W' : "—" }}</b></button>
        <button class="asset-action"><span>Rank</span><b>{{ wallet.isConnected ? '#42' : "—" }}</b></button>
      </div>
    </Card>

    <!-- ═══ 3. Protocol ═══ -->
    <div class="section">
      <SectionHead title="Protocol">
        <template #actions><button class="text-btn">Details</button></template>
      </SectionHead>
      <div class="protocol-strip">
        <div class="protocol-item"><span>Buy tax (to dividend pool)</span><b>4%</b><small>BUY_TAX_BPS=400</small></div>
        <div class="protocol-item"><span>Buyback size</span><b>0.01 BNB</b><small>SupportPool → BuybackLocker</small></div>
        <div class="protocol-item"><span>Min interval</span><b>60s</b><small>MIN_BUYBACK_INTERVAL</small></div>
      </div>
    </div>

    <!-- ═══ 4. Why BGP ═══ -->
    <div class="section why-banner" v-if="isPreview">
      <div class="eyebrow">WHY BGP</div>
      <h2>Clarity you can act on.</h2>
      <p>A focused Web3 experience built around transparent mechanics, community participation and long-term alignment.</p>
      <div class="why-pills">
        <span>Precision</span><span>Participation</span><span>Commitment</span>
      </div>
    </div>

    <!-- ═══ 5. Holder Ranking ═══ -->
    <div class="section" id="rankingSection">
      <SectionHead title="Holder ranking">
        <template #actions><Tag variant="demo">Preview data</Tag></template>
      </SectionHead>
      <div class="rank-list">
        <div v-for="r in rankData" :key="r.no" class="rank-row">
          <div class="rank-no">{{ r.no }}</div>
          <div class="rank-user"><b>{{ r.addr }}</b><span>{{ r.label }}</span></div>
          <div class="rank-side">
            <strong>{{ r.amount }}</strong>
            <Tag :variant="r.tagVariant">{{ r.lockLabel }}&nbsp;{{ r.lockAmount }}</Tag>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
/* ── Hero ── */
.hero {
  position: relative; overflow: hidden; min-height: 314px; border-radius: 25px;
  padding: 28px 20px 22px;
  background-image: linear-gradient(90deg, rgba(7,10,20,.99), rgba(7,10,20,.82) 56%, rgba(7,10,20,.16));
  display: flex; flex-direction: column; justify-content: flex-end;
}
.hero-topline { display: flex; align-items: center; gap: 12px; }
.hero-network { display: flex; align-items: center; gap: 5px; font-size: 9px; color: var(--text-3); }
.hero-network i { width: 6px; height: 6px; border-radius: 50%; background: var(--green); }
.hero-copy { margin-top: 8px; }
.hero-copy h1 { font-size: 39px; line-height: 1.02; letter-spacing: -.045em; margin: 9px 0 11px; max-width: 315px; }
.hero-copy p { font-size: 13px; line-height: 1.55; color: var(--text-2); max-width: 305px; }
.hero-market { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-top: 16px; }
.hero-market div span { display: block; font-size: 9px; color: var(--text-3); }
.hero-market div b { display: block; font-size: 12px; margin-top: 5px; }
.hero-change { font-style: normal; }
.hero-actions { display: grid; grid-template-columns: 1.2fr 1fr; gap: 9px; margin-top: 21px; max-width: 310px; }
.hero-actions .btn { text-align: center; }

/* ── Value chips ── */
.value-strip { display: flex; gap: 8px; overflow-x: auto; margin: 17px -4px -2px; padding: 0 4px 3px; scrollbar-width: none; width: calc(100% + 8px); }
.value-strip::-webkit-scrollbar { display: none; }
.value-chip { flex: 0 0 170px; padding: 12px; border-radius: 15px; background: rgba(14,20,34,.86); box-shadow: inset 0 1px 0 rgba(255,255,255,.04); }
.value-chip i { display: block; width: 17px; height: 2px; border-radius: 2px; background: linear-gradient(90deg, var(--gold), var(--cyan)); margin-bottom: 9px; }
.value-chip b { display: block; font-size: 11px; }
.value-chip span { display: block; font-size: 9px; color: var(--text-3); line-height: 1.42; margin-top: 4px; }

/* ── Wallet ── */
.wallet-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.wallet-top h2 { margin: 0; font-size: 13px; }
.wallet-top small { display: block; font-size: 9px; color: var(--text-3); margin-top: 4px; }
.wallet-chart-row { display: flex; justify-content: space-between; align-items: flex-end; gap: 14px; margin-top: 14px; }
.asset-main b { font-size: 34px; letter-spacing: -.04em; }
.asset-main span { display: block; font-size: 9px; color: var(--text-3); margin-top: 5px; }
.asset-main strong { font-size: 13px; }
.asset-change { margin-top: 7px; }
.asset-change span { display: inline; margin-left: 7px; }
.mini-spark { flex-shrink: 0; width: 112px; margin-left: auto; }
.mini-spark svg { width: 100%; height: auto; }
.asset-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-top: 14px; }
.asset-action { border: 0; border-radius: 14px; padding: 12px 10px; background: rgba(255,255,255,.027); color: var(--text); text-align: left; box-shadow: inset 0 1px 0 rgba(255,255,255,.035); cursor: pointer; }
.asset-action span { display: block; font-size: 8px; color: var(--text-3); }
.asset-action b { display: block; font-size: 14px; margin-top: 5px; }

/* ── Protocol ── */
.protocol-strip { display: flex; gap: 9px; overflow-x: auto; scrollbar-width: none; }
.protocol-strip::-webkit-scrollbar { display: none; }
.protocol-item { flex: 0 0 151px; min-height: 108px; padding: 14px; border-radius: 16px; background: linear-gradient(150deg, rgba(18,26,43,.94), rgba(10,15,27,.98)); box-shadow: inset 0 1px 0 rgba(255,255,255,.04); display: flex; flex-direction: column; justify-content: space-between; }
.protocol-item span { font-size: 9px; color: var(--text-3); }
.protocol-item b { font-size: 19px; color: var(--gold); }
.protocol-item small { font-size: 8px; color: var(--text-3); }
.text-btn { border: 0; background: none; color: var(--text-3); font-size: 9px; font-weight: 800; cursor: pointer; }

/* ── Why BGP ── */
.why-banner {
  position: relative; overflow: hidden; min-height: 232px; padding: 22px 20px;
  border-radius: 24px; margin-top: var(--section-gap);
  background-image: linear-gradient(90deg, rgba(8,12,23,.98), rgba(8,12,23,.88) 52%, rgba(8,12,23,.25));
}
.why-banner h2 { font-size: 22px; letter-spacing: -.02em; margin: 13px 0 11px; }
.why-banner p { font-size: 12px; color: var(--text-2); line-height: 1.6; }
.why-pills { display: flex; gap: 8px; margin-top: 17px; }
.why-pills span { height: 32px; padding: 0 12px; border-radius: 99px; border: 1px solid rgba(76,201,240,.16); background: rgba(76,201,240,.05); color: #DFF8FF; font-size: 10px; display: grid; place-items: center; }

/* ── Ranking ── */
.rank-list { padding: 5px 16px 4px; border-radius: 20px; background: rgba(12,17,29,.72); box-shadow: inset 0 1px 0 rgba(255,255,255,.035); }
.rank-row { display: grid; grid-template-columns: 28px minmax(0,1fr) minmax(104px,auto); gap: 10px; align-items: center; padding: 13px 0; border-top: 1px solid rgba(255,255,255,.05); }
.rank-row:first-child { border-top: 0; margin: 0 -8px 3px; padding: 14px 8px; border-radius: 14px; background: linear-gradient(90deg, rgba(228,185,107,.07), rgba(76,201,240,.035)); }
.rank-no { font-size: 11px; color: var(--text-3); font-weight: 850; }
.rank-row:first-child .rank-no { color: var(--gold); }
.rank-user b { display: block; font-size: 11px; }
.rank-user span { display: block; font-size: 8px; color: var(--text-3); margin-top: 4px; }
.rank-side { text-align: right; }
.rank-side strong { display: block; font-size: 10px; }

@media (max-width: 370px) {
  .hero-actions { grid-template-columns: 1fr; }
  .asset-grid { gap: 6px; }
  .asset-action { padding: 11px 7px; }
}
</style>
