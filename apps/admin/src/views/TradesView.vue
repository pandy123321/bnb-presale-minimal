<!--
  PANGU2 Admin — TradesView (Transaction Monitoring)
  Displays mock transaction data. API integration reserved for when transaction sync is live.
-->
<script setup lang="ts">
import { useAdminTransactions } from "@/features/dashboard/useAdminApi";

const txs = useAdminTransactions();
</script>

<template>
  <div>
    <div class="hero">
      <div>
        <h3>交易与税费</h3>
        <p>查询买卖记录和税费分桶。后台不得独立计算或修改用户税率。当前为 MOCK DATA。</p>
      </div>
      <div class="hero-side">
        <strong>{{ txs.total }}笔</strong>
        <small>MOCK DATA</small>
      </div>
    </div>

    <div class="section-head"><h3>交易列表</h3></div>

    <div v-if="txs.loading" class="loading-row">Loading transactions...</div>
    <div v-else class="card">
      <div class="card-body">
        <div class="table">
          <div class="tr trades head">
            <span>类型</span><span>买家</span><span>BNB</span><span>Token</span><span>税率</span><span>状态</span><span>区块</span>
          </div>
          <div
            v-for="tx in txs.transactions"
            :key="tx.tx_hash"
            class="tr trades"
          >
            <span>{{ tx.type === 'buy' ? '买入' : '卖出' }}</span>
            <span class="mono copy">{{ tx.buyer }}</span>
            <span>{{ tx.amount_bnb }}</span>
            <span>{{ tx.amount_token }}</span>
            <span :class="{ 'tax-high': tx.tax_rate === '10%' }">{{ tx.tax_rate }}</span>
            <span class="tag" :class="tx.status === 'confirmed' ? 'ok' : 'warning'">
              {{ tx.status === 'confirmed' ? '已确认' : tx.status }}
            </span>
            <span class="mono">#{{ tx.block_number }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 20px;
  align-items: end;
  padding: 22px;
  border: 1px solid rgba(214,173,95,.22);
  background: linear-gradient(135deg, rgba(214,173,95,.11), rgba(17,19,24,.96) 48%, rgba(17,19,24,.78));
}
.hero h3 { font-size: 24px; margin: 0; font-weight: 740; }
.hero p { color: var(--muted); font-size: 12px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { color: var(--muted); font-size: 10px; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }

.table { min-width: 900px; overflow: auto; }
.tr {
  display: grid;
  gap: 12px;
  align-items: center;
  min-height: 48px;
  padding: 8px 14px;
  border-bottom: 1px solid rgba(255,255,255,.05);
  font-size: 11px;
}
.tr.head { min-height: 38px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
.tr.trades { grid-template-columns: .7fr 1fr .6fr .9fr .6fr .7fr .8fr; }
.copy { color: var(--gold2); cursor: pointer; }

.tax-high { color: var(--red); font-weight: 700; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }

.loading-row { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }

.mono { font-family: monospace; font-size: 10px; }

@media (max-width: 1180px) { .hero { grid-template-columns: 1fr; } }
</style>
