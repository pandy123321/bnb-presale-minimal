<script setup lang="ts">
import { computed } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import Card from "@pangu2/ui/components/Card.vue";
import Button from "@pangu2/ui/components/Button.vue";
import Tag from "@pangu2/ui/components/Tag.vue";
import SectionHead from "@pangu2/ui/components/SectionHead.vue";

const wallet = useWalletStore();
const hasWallet = computed(() => wallet.isConnected);
const noData = "\u2014"; // em-dash

const shortAddr = computed(() =>
  hasWallet.value
    ? `${wallet.address?.slice(0, 6)}\u2026${wallet.address?.slice(-4)}`
    : "Connect to view"
);
</script>

<template>
  <div class="page-portfolio">
    <div class="page-title">
      <h1>Portfolio</h1>
      <p>Asset overview, staking, and team referrals.</p>
    </div>
    <Tag variant="demo" style="margin-bottom: 12px"
      >Data syncing — connect wallet and wait for chain sync</Tag
    >

    <!-- ═══ 1. Asset Overview ═══ -->
    <Card>
      <div class="portfolio-top">
        <div>
          <h2>Wallet position</h2>
          <small>{{ shortAddr }} · {{ hasWallet ? "Live" : "Demo" }}</small>
        </div>
        <Tag variant="demo">Syncing</Tag>
      </div>
      <div class="asset-main-row">
        <div>
          <b>{{ hasWallet ? noData : noData }}</b><span>BGP balance</span>
        </div>
        <div class="asset-right">
          <strong class="green">{{ noData }}</strong
          ><span>{{ noData }} BNB</span>
        </div>
      </div>
      <div class="asset-stats-grid">
        <div><span>Locked</span><b>{{ noData }}</b></div>
        <div><span>Available</span><b>{{ noData }}</b></div>
        <div><span>Locked ratio</span><b>{{ noData }}</b></div>
      </div>
    </Card>

    <!-- ═══ 2. Asset Distribution ═══ -->
    <div class="section">
      <SectionHead title="Asset distribution">
        <template #actions><Tag variant="demo">Syncing</Tag></template>
      </SectionHead>
      <div class="donut-row">
        <div class="donut-placeholder">
          <svg viewBox="0 0 48 48" fill="none">
            <circle cx="24" cy="24" r="20" stroke="var(--line)" stroke-width="2"/>
            <path d="M12 12l24 24" stroke="var(--text-3)" stroke-width="1" opacity="0.3"/>
          </svg>
          <b>{{ noData }}</b
          ><span>Total</span>
        </div>
        <div class="donut-legend">
          <div class="legend-item">
            <i class="legend-cyan"></i><span>Locked</span><b>{{ noData }}</b
            ><small>{{ noData }}%</small>
          </div>
          <div class="legend-item">
            <i class="legend-gold"></i><span>Available</span
            ><b>{{ noData }}</b
            ><small>{{ noData }}%</small>
          </div>
          <div class="legend-item">
            <i class="legend-violet"></i><span>Rewards</span
            ><b>{{ noData }}</b
            ><small>{{ noData }}%</small>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══ 3. Staking ═══ -->
    <div class="section">
      <SectionHead title="Staking">
        <template #actions
          ><button type="button" class="text-btn">Lock BGP</button></template
        >
      </SectionHead>
      <Card variant="soft">
        <div class="staking-grid">
          <div class="staking-metric">
            <span>Staked</span><b>{{ noData }}</b>
          </div>
          <div class="staking-metric">
            <span>Rewards</span><b class="gold">{{ noData }}</b>
          </div>
          <div class="staking-metric">
            <span>APR</span><b>{{ noData }}</b>
          </div>
        </div>
        <Button variant="primary" class="stake-btn" disabled
          >Staking not yet available</Button
        >
      </Card>
    </div>

    <!-- ═══ 4. My Team ═══ -->
    <div class="section">
      <SectionHead title="My team">
        <template #actions><Tag variant="demo">Coming soon</Tag></template>
      </SectionHead>
      <div class="team-empty">
        <b>Team features coming soon</b>
        <small>Referral tracking will be available after contract deployment.</small>
      </div>
    </div>

    <!-- ═══ 5. Share BGP ═══ -->
    <div class="section">
      <Card variant="soft">
        <div class="share-card">
          <div>
            <b>Share BGP</b
            ><small class="referral-code"
              >Referrals not yet available</small
            >
          </div>
          <Button variant="primary" class="share-btn" disabled>Share</Button>
        </div>
      </Card>
    </div>

    <!-- ═══ 6. Buyback Batches ═══ -->
    <div class="section">
      <SectionHead title="Buyback batches">
        <template #actions><Tag variant="demo">Coming soon</Tag></template>
      </SectionHead>
      <div class="batch-empty">
        <b>No buyback batches yet</b>
        <small>Buyback data will appear once the chain worker confirms on-chain events.</small>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ── Asset ── */
.portfolio-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}
.portfolio-top h2 {
  margin: 0;
  font-size: 13px;
}
.portfolio-top small {
  display: block;
  font-size: 9px;
  color: var(--text-3);
  margin-top: 4px;
}
.asset-main-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 14px;
  margin-top: 17px;
}
.asset-main-row b {
  font-size: 34px;
  letter-spacing: -0.04em;
}
.asset-main-row span {
  display: block;
  font-size: 9px;
  color: var(--text-3);
  margin-top: 5px;
}
.asset-right {
  text-align: right;
}
.asset-right strong {
  font-size: 13px;
}
.asset-right span {
  display: block;
  font-size: 9px;
  color: var(--text-3);
  margin-top: 4px;
}
.asset-stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  margin-top: 14px;
}
.asset-stats-grid div {
  padding: 10px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.02);
}
.asset-stats-grid span {
  display: block;
  font-size: 8px;
  color: var(--text-3);
}
.asset-stats-grid b {
  display: block;
  font-size: 14px;
  margin-top: 4px;
}

/* ── Donut placeholder ── */
.donut-row {
  display: flex;
  align-items: center;
  gap: 20px;
}
.donut-placeholder {
  width: 120px;
  height: 120px;
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  position: relative;
}
.donut-placeholder svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.donut-placeholder b {
  font-size: 14px;
}
.donut-placeholder span {
  font-size: 8px;
  color: var(--text-3);
}
.donut-legend {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.legend-item {
  display: flex;
  align-items: center;
  gap: 9px;
}
.legend-item i {
  width: 10px;
  height: 10px;
  border-radius: 3px;
  flex-shrink: 0;
}
.legend-cyan {
  background: var(--cyan);
}
.legend-gold {
  background: var(--gold);
}
.legend-violet {
  background: var(--violet);
}
.legend-item span {
  font-size: 10px;
  color: var(--text-2);
  flex: 1;
}
.legend-item b {
  font-size: 12px;
}
.legend-item small {
  font-size: 9px;
  color: var(--text-3);
  margin-left: 6px;
}

/* ── Staking ── */
.staking-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}
.staking-metric {
  text-align: center;
}
.staking-metric span {
  display: block;
  font-size: 9px;
  color: var(--text-3);
}
.staking-metric b {
  display: block;
  font-size: 20px;
  margin-top: 6px;
}
.stake-btn {
  width: 100%;
  margin-top: 14px;
}

/* ── Team / Batch empty states ── */
.team-empty,
.batch-empty {
  padding: 24px 16px;
  border-radius: 16px;
  background: rgba(12, 17, 29, 0.72);
  text-align: center;
}
.team-empty b,
.batch-empty b {
  display: block;
  font-size: 12px;
  color: var(--text-2);
  margin-bottom: 6px;
}
.team-empty small,
.batch-empty small {
  font-size: 10px;
  color: var(--text-3);
  line-height: 1.5;
}

/* ── Share ── */
.share-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.share-card b {
  display: block;
  font-size: 13px;
}
.referral-code {
  display: block;
  font-size: 9px;
  color: var(--text-3);
  margin-top: 4px;
}
.share-btn {
  min-height: 42px;
}

.text-btn {
  border: 0;
  background: none;
  color: var(--text-3);
  font-size: 9px;
  font-weight: 800;
  cursor: pointer;
}
</style>
