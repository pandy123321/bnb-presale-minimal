<!--
  PANGU2 Admin — GovernanceView (Jobs + Audit)
-->
<script setup lang="ts">
import { useJobs } from "@/features/jobs/useJobs";
import { useAudit } from "@/features/audit/useAudit";

const jobs = useJobs();
const audit = useAudit();
</script>

<template>
  <div>
    <div class="hero">
      <div><h3>系统治理与审计</h3><p>任务监控、权限矩阵、审计日志。危险操作需要二次确认。</p></div>
      <div class="hero-side"><strong>{{ jobs.jobs.length }}个任务</strong><small>{{ audit.total }}条审计</small></div>
    </div>

    <!-- ══ Jobs ══ -->
    <div class="section-head"><h3>任务中心</h3></div>
    <div v-if="jobs.loading" class="loading">Loading jobs...</div>
    <div v-else-if="jobs.error" class="err">{{ jobs.error }}</div>
    <div v-else class="card"><div class="card-body">
      <div class="table">
        <div class="tr jobs head"><span>任务名</span><span>状态</span><span>处理/错误</span><span>最后运行</span><span>操作</span></div>
        <div v-for="j in jobs.jobs" :key="j.name" class="tr jobs">
          <span><b>{{ j.name }}</b><small>{{ j.run_id?.slice(0,12) ?? '—' }}</small></span>
          <span class="tag" :class="{ ok: j.status==='HEALTHY'||j.status==='RUNNING', gold: j.status==='IDLE', danger: j.status==='FAILED'||j.status==='DEGRADED' }">{{ jobs.statusLabel(j.status) }}</span>
          <span>{{ j.processed ?? 0 }} / {{ j.errors ?? 0 }}</span>
          <span>{{ j.last_run ? new Date(j.last_run).toLocaleString() : '—' }}</span>
          <span>
            <button v-if="j.status==='FAILED'||j.status==='DEGRADED'" class="rbtn" @click="jobs.requestRetry(j.name)">重试</button>
            <span v-if="jobs.retryingJob===j.name" class="retrying">重试中...</span>
            <span v-if="j.last_error" class="errhint" :title="j.last_error">ⓘ</span>
          </span>
        </div>
      </div>
    </div></div>

    <!-- Retry Confirm Modal -->
    <Transition name="modal">
      <div v-if="jobs.retryConfirm" class="moverlay" @click.self="jobs.cancelRetry()">
        <div class="mpanel">
          <b>确认重试任务</b>
          <p>任务 <code>{{ jobs.retryConfirm }}</code> 将被重新触发。此操作需要 Idempotency-Key 保证幂等性。</p>
          <div class="mbtns"><button class="btn danger" @click="jobs.confirmRetry()">确认重试</button><button class="btn sec" @click="jobs.cancelRetry()">取消</button></div>
          <small v-if="jobs.retryMsg" :class="{ ok: jobs.retryMsg.includes('已排队') }">{{ jobs.retryMsg }}</small>
        </div>
      </div>
    </Transition>

    <!-- ══ RBAC ══ -->
    <div class="section-head"><h3>角色权限矩阵</h3></div>
    <div class="card"><div class="card-body">
      <div class="table">
        <div class="tr rbac head"><span>角色</span><span>仪表盘</span><span>合约</span><span>任务</span><span>重试</span><span>审计</span><span>写链</span></div>
        <div class="tr rbac"><span><b>SUPER_ADMIN</b></span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span></div>
        <div class="tr rbac"><span><b>OPERATOR</b></span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span>—</span><span>—</span></div>
        <div class="tr rbac"><span><b>AUDITOR</b></span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span>—</span><span class="tag ok">✓</span><span>—</span></div>
        <div class="tr rbac"><span><b>VIEWER</b></span><span class="tag ok">✓</span><span class="tag ok">✓</span><span class="tag ok">✓</span><span>—</span><span>—</span><span>—</span></div>
      </div>
    </div></div>

    <!-- ══ Audit Logs ══ -->
    <div class="section-head"><h3>审计日志</h3></div>
    <div class="filters">
      <select v-model="audit.filterAction" @change="audit.fetch()"><option value="">全部动作</option><option value="JOB_RETRY_QUEUED">任务重试</option><option value="WALLET_AUTHENTICATED">钱包认证</option><option value="WALLET_LOGGED_OUT">钱包登出</option></select>
      <input v-model="audit.filterAdmin" placeholder="管理员邮箱..." class="finp" @keyup.enter="audit.fetch()" />
      <span class="ftotal">{{ audit.total }} 条</span>
    </div>
    <div v-if="audit.loading" class="loading">Loading audit...</div>
    <div v-else-if="audit.error" class="err">{{ audit.error }}</div>
    <div v-else class="card"><div class="card-body">
      <div class="table">
        <div class="tr audit head"><span>ID</span><span>管理员</span><span>动作</span><span>目标</span><span>结果</span><span>IP</span><span>时间</span></div>
        <div v-for="a in audit.logs" :key="a.id" class="tr audit">
          <span class="mono">#{{ a.id }}</span>
          <span><b>{{ a.admin_email }}</b><small>{{ a.admin_role }}</small></span>
          <span>{{ a.action }}</span><span>{{ a.target_type ?? '—' }}</span>
          <span class="tag" :class="{ ok: a.result==='SUCCESS', danger: a.result!=='SUCCESS' }">{{ audit.resultLabel(a.result) }}</span>
          <span class="mono">{{ a.ip_address ?? '—' }}</span>
          <span class="mono">{{ new Date(a.created_at).toLocaleString() }}</span>
        </div>
        <div v-if="audit.logs.length===0" class="empty">暂无审计记录</div>
      </div>
    </div></div>
  </div>
</template>

<style scoped>
.hero { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 20px; align-items: end; padding: 22px; border: 1px solid rgba(214,173,95,.22); background: linear-gradient(135deg, rgba(214,173,95,.11), rgba(17,19,24,.96) 48%, rgba(17,19,24,.78)); }
.hero h3 { font-size: 24px; margin: 0; font-weight: 740; }
.hero p { color: var(--muted); font-size: 12px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { color: var(--muted); font-size: 10px; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }
.table { min-width: 900px; overflow: auto; }
.tr { display: grid; gap: 10px; align-items: center; min-height: 44px; padding: 6px 12px; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 11px; }
.tr.head { min-height: 34px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
.tr.jobs { grid-template-columns: 1.2fr .8fr .8fr 1fr .8fr; }
.tr.rbac { grid-template-columns: 1fr .6fr .6fr .6fr .6fr .6fr .6fr; }
.tr.audit { grid-template-columns: .4fr 1fr 1fr .7fr .5fr .8fr 1fr; }
.tr b { display: block; }
.tr small { display: block; color: var(--muted); font-size: 9px; margin-top: 1px; }
.loading, .empty { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }
.err { padding: 12px; color: var(--red); background: rgba(255,116,125,.04); border: 1px solid rgba(255,116,125,.15); border-radius: 8px; font-size: 12px; }
.rbtn { height: 28px; padding: 0 12px; border: 1px solid var(--line); background: rgba(255,255,255,.04); color: var(--gold2); border-radius: 6px; font-size: 10px; font-weight: 700; cursor: pointer; }
.rbtn:hover { background: rgba(216,170,81,.1); }
.retrying { font-size: 10px; color: var(--orange); }
.errhint { color: var(--red); cursor: help; font-size: 13px; }
.filters { display: flex; gap: 8px; align-items: center; margin-bottom: 10px; flex-wrap: wrap; }
.filters select, .finp { height: 32px; padding: 0 10px; border: 1px solid var(--line); background: var(--panel2); color: var(--text); font-size: 11px; border-radius: 6px; outline: 0; }
.finp { min-width: 150px; }
.ftotal { font-size: 10px; color: var(--muted); margin-left: auto; }
.moverlay { position: fixed; inset: 0; z-index: 80; background: rgba(0,0,0,.65); display: grid; place-items: center; }
.mpanel { width: 100%; max-width: 400px; background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 24px; }
.mpanel b { font-size: 15px; }
.mpanel p { color: var(--muted); font-size: 11px; margin: 8px 0 16px; line-height: 1.5; }
.mpanel code { color: var(--gold2); font-size: 10px; }
.mbtns { display: flex; gap: 8px; }
.mpanel small { display: block; margin-top: 10px; font-size: 10px; }
.mpanel small.ok { color: var(--green); }
.btn { flex: 1; height: 38px; border: 0; border-radius: 8px; font-weight: 700; font-size: 12px; cursor: pointer; }
.btn.danger { background: var(--red); color: #fff; }
.btn.sec { background: rgba(255,255,255,.05); color: var(--muted); border: 1px solid var(--line); }
.modal-enter-active, .modal-leave-active { transition: opacity .2s; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.mono { font-family: monospace; font-size: 10px; }
@media (max-width: 820px) { .hero { grid-template-columns: 1fr; } }
</style>
