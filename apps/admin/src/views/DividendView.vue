<!--
  PANGU2 Admin — DividendView (Epoch Management)
  Connects to /dividend/epochs/current + /admin/dashboard APIs.
  Shows epoch lifecycle: pending → snapshot → proof → claim_open → closed.
-->
<script setup lang="ts">
import { computed } from "vue";
import { useEpochs } from "@/features/epochs/useEpochs";

const eps = useEpochs();

const epochSteps = computed(() => {
  if (!eps.current.value) return [];
  const s = eps.current.value.status;
  const order = ["pending", "snapshot_complete", "proof_generated", "claim_open", "closed"];
  const labels = ["快照", "排名计算", "生成Proof", "开放领取", "关闭"];
  return order.map((k, i) => ({ key: k, label: labels[i], done: order.indexOf(s) > i || s === k, active: s === k }));
});

const heroStatus = computed(() =>
  eps.current.value?.status === "claim_open" ? "领取开放"
  : eps.current.value?.status === "closed" ? "已关闭"
  : eps.current.value?.status === "proof_generated" ? "Proof就绪"
  : "运行中",
);
</script>

<template>
  <div>
    <div class="hero">
      <div>
        <h3>前100名分红管理</h3>
        <p>固定快照区块、计算有效持币、生成四档分配与Merkle Root。</p>
      </div>
      <div class="hero-side">
        <strong v-if="eps.current">Epoch {{ eps.current.epoch_id }}</strong>
        <strong v-else>—</strong>
        <small>{{ heroStatus }}</small>
      </div>
    </div>

    <div v-if="eps.loading" class="loading-row">Loading epochs...</div>
    <div v-if="eps.error" class="err-row">{{ eps.error }}</div>

    <!-- KPI Grid -->
    <div class="kpi-grid" v-if="eps.current">
      <div class="kpi"><div class="kpi-head"><span>当前Epoch</span></div><strong>{{ eps.current.epoch_id }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>快照区块</span></div><strong>#{{ eps.current.snapshot_block }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>分红总量</span></div><strong>{{ eps.current.total_dividend_raw }}</strong></div>
      <div class="kpi"><div class="kpi-head"><span>Merkle Root</span></div><strong class="mono">{{ eps.current.merkle_root?.slice(0, 10) }}...</strong></div>
    </div>

    <!-- Epoch Lifecycle -->
    <div class="section-head"><h3>Epoch流程</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="stepper">
          <div v-for="st in epochSteps" :key="st.key" class="step" :class="{ done: st.done, active: st.active }">
            <b>{{ st.label }}</b>
            <span v-if="st.key === 'pending' && eps.current">等待快照</span>
            <span v-else-if="st.key === 'snapshot_complete' && eps.current">#{{ eps.current.snapshot_block }}</span>
            <span v-else-if="st.key === 'proof_generated' && eps.current">{{ eps.current.merkle_root?.slice(0, 8) }}...</span>
            <span v-else-if="st.active">进行中</span>
            <span v-else-if="st.done">✓</span>
            <span v-else>—</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Tier Allocation -->
    <div class="section-head"><h3>排名与分配</h3></div>
    <div class="layout-2">
      <div class="card">
        <div class="card-body">
          <div class="table">
            <div class="tr head"><span>档位</span><span>排名</span><span>分配比</span></div>
            <div v-for="t in eps.tiers" :key="t.name" class="tr">
              <span>{{ t.name }}</span><span>{{ t.rank_range }}</span><span>{{ t.share_percent }}%</span>
            </div>
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-head"><h4>Root提案时间线</h4><span class="tag ok" v-if="eps.current">Epoch {{ eps.current.epoch_id }}</span></div>
        <div class="card-body">
          <div class="metric-row"><span>分红总额(RAW)</span><b class="mono">{{ eps.current?.total_dividend_raw ?? '—' }}</b></div>
          <div class="metric-row"><span>Merkle Root</span><b class="mono">{{ eps.current?.merkle_root?.slice(0, 14) ?? '—' }}...</b></div>
          <div class="metric-row"><span>Artifact Checksum</span><b class="mono">{{ eps.current?.merkle_root?.slice(0, 14) ?? '—' }}</b></div>
          <div class="metric-row"><span>状态</span><b>{{ eps.statusLabel(eps.current?.status ?? 'pending') }}</b></div>
        </div>
      </div>
    </div>

    <!-- Epoch History -->
    <div class="section-head"><h3>历史Epoch</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="table">
          <div class="tr head"><span>Epoch</span><span>状态</span><span>快照区块</span><span>Merkle Root</span></div>
          <div v-for="e in eps.epochs" :key="e.epoch_id" class="tr">
            <span>{{ e.epoch_id }}</span>
            <span class="tag" :class="{ ok: e.status === 'claim_open' || e.status === 'proof_generated', gold: e.status === 'closed', warn: e.status === 'pending' }">
              {{ eps.statusLabel(e.status) }}
            </span>
            <span class="mono">#{{ e.snapshot_block }}</span>
            <span class="mono">{{ e.merkle_root?.slice(0, 14) ?? '—' }}...</span>
          </div>
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
.kpi strong { display: block; font-size: 20px; margin-top: 9px; font-weight: 720; word-break: break-all; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }
.stepper { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 5px; }
.step { border-top: 2px solid var(--line); padding: 10px 7px; color: var(--muted); font-size: 10px; }
.step b { display: block; font-size: 11px; color: var(--text); margin-bottom: 2px; }
.step.done { border-top-color: var(--green); }
.step.active { border-top-color: var(--gold); color: var(--gold2); }
.table { min-width: 500px; overflow: auto; }
.tr { display: grid; grid-template-columns: repeat(4, minmax(100px, 1fr)); gap: 12px; align-items: center; min-height: 44px; padding: 6px 14px; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.tr.head { min-height: 34px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
.layout-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 10px; }
.metric-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.metric-row:last-child { border-bottom: 0; }
.metric-row span { color: var(--muted); }
.loading-row, .err-row { padding: 16px; text-align: center; font-size: 12px; }
.err-row { color: var(--red); background: rgba(255,116,125,.04); border: 1px solid rgba(255,116,125,.15); border-radius: 8px; }
.mono { font-family: monospace; font-size: 10px; }
@media (max-width: 1180px) { .kpi-grid, .stepper { grid-template-columns: repeat(3, 1fr); } .layout-2 { grid-template-columns: 1fr; } }
</style>
