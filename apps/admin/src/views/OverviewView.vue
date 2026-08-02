<!--
  PANGU2 Admin — OverviewView (Dashboard)
  Connects to /config, /system-status, /contracts APIs.
  ═══════════════════════════════════════════
-->
<script setup lang="ts">
import { useAdminConfig, useAdminSystemStatus, useAdminContracts } from "@/features/dashboard/useAdminApi";

const config = useAdminConfig();
const sysStatus = useAdminSystemStatus();
const contracts = useAdminContracts();
</script>

<template>
  <div>
    <!-- Hero -->
    <div class="hero">
      <div>
        <h3>PANGU2 链上运营总览</h3>
        <p>
          {{ config.chainName }}
          <span v-if="config.chainId"> · Chain {{ config.chainId }}</span>
          <span> · RPC {{ config.rpcStatus }}</span>
        </p>
        <p style="margin-top:4px">
          监控交易税费、分红资金、托底回购、锁仓、任务与治理状态。
        </p>
      </div>
      <div class="hero-side">
        <strong v-if="sysStatus.latestBlock !== '—'">#{{ sysStatus.latestBlock }}</strong>
        <strong v-else>—</strong>
        <small v-if="sysStatus.blockLag !== null">Block Lag: {{ sysStatus.blockLag }} · Queue: {{ sysStatus.queueStatus }}</small>
        <small v-if="sysStatus.openAnomalies > 0" style="color:var(--red)">{{ sysStatus.openAnomalies }} anomaly{{ sysStatus.openAnomalies > 1 ? 'ies' : '' }}</small>
        <small v-else style="color:var(--green)">0 anomalies</small>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="config.loading" class="loading-row">Loading config...</div>

    <!-- KPI Grid -->
    <div class="kpi-grid">
      <div class="kpi">
        <div class="kpi-head"><span>Chain</span></div>
        <strong>{{ config.chainName }}</strong>
        <footer>ID: {{ config.chainId ?? '—' }}</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>Latest Block</span></div>
        <strong>{{ sysStatus.latestBlock }}</strong>
        <footer>Scanned: {{ sysStatus.lastScanned }}</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>Block Lag</span></div>
        <strong>{{ sysStatus.blockLag !== null ? sysStatus.blockLag : '—' }}</strong>
        <footer>Queue: {{ sysStatus.queueStatus }}</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>Anomalies</span></div>
        <strong>{{ sysStatus.openAnomalies }}</strong>
        <footer>{{ sysStatus.openAnomalies === 0 ? 'All clear' : 'Needs attention' }}</footer>
      </div>
    </div>

    <!-- Section: Running Services -->
    <div class="section-head"><h3>运行服务</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="status-row">
          <b>RPC Status</b>
          <span class="tag" :class="config.rpcStatus === 'OK' ? 'ok' : 'warning'">{{ config.rpcStatus }}</span>
        </div>
        <div class="status-row">
          <b>Queue Worker</b>
          <span class="tag" :class="sysStatus.queueStatus === 'HEALTHY' ? 'ok' : 'warning'">{{ sysStatus.queueStatus }}</span>
        </div>
        <div class="status-row">
          <b>Supported Networks</b>
          <span>{{ config.supportedNetworks.join(', ') }}</span>
        </div>
      </div>
    </div>

    <!-- Section: Contract Registry -->
    <div class="section-head"><h3>合约注册表</h3></div>
    <div v-if="contracts.loading" class="loading-row">Loading contracts...</div>
    <div v-else-if="contracts.error" class="error-row">{{ contracts.error }}</div>
    <div v-else>
      <div class="card" v-for="c in contracts.contracts" :key="c.name" style="margin-bottom:8px">
        <div class="card-body">
          <div class="contract-row">
            <b>{{ c.name }}</b>
            <span class="tag" :class="c.status === 'ACTIVE' ? 'ok' : (c.status === 'PAUSED' ? 'warning' : 'danger')">
              {{ c.status }}
            </span>
          </div>
          <div class="contract-meta">
            <span>Address: {{ c.address }}</span>
            <span>ABI v{{ c.abi_version }}</span>
            <span>Deployed @ block #{{ c.deployment_block }}</span>
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
.hero p { color: var(--muted); font-size: 12px; max-width: 760px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { display: block; color: var(--muted); font-size: 10px; margin-top: 2px; }

.kpi-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-top: 12px; }
.kpi { border: 1px solid var(--line); background: var(--panel); padding: 16px; }
.kpi-head { display: flex; justify-content: space-between; color: var(--muted); font-size: 11px; }
.kpi strong { display: block; font-size: 23px; margin-top: 9px; font-weight: 720; }
.kpi footer { display: flex; justify-content: space-between; margin-top: 6px; color: var(--muted); font-size: 10px; }

.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }

.status-row { display: flex; align-items: center; justify-content: space-between; padding: 11px 0; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 12px; }
.status-row:last-child { border-bottom: 0; }

.contract-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 13px; }
.contract-meta { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 8px; font-size: 10px; color: var(--muted); }

.loading-row { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }
.error-row { padding: 16px; border: 1px solid rgba(255,116,125,.2); background: rgba(255,116,125,.04); color: var(--red); font-size: 12px; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }
.tag.danger { color: var(--red); background: rgba(255,116,125,.08); border: 1px solid rgba(255,116,125,.18); }

@media (max-width: 1180px) { .kpi-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 520px) { .kpi-grid { grid-template-columns: 1fr; } }
</style>
