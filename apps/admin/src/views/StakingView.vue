<!--
  PANGU2 Admin — StakingView (锁仓管理)
  KPI卡片 → 管理操作(充值/设速率+二次确认) → 仓位查询 → 锁仓列表
-->
<script setup lang="ts">
import { ref, computed } from "vue";
import { useAdminStaking } from "@/features/staking/useAdminStaking";

const staking = useAdminStaking();

// ── Admin action inputs ─────────────────────
const fundAmount = ref("");
const rewardRateInput = ref("");

// ── Position detail expand ──────────────────
const expandedPosition = ref<string | null>(null);
function toggleExpand(posId: string) {
  expandedPosition.value = expandedPosition.value === posId ? null : posId;
}

// ── Helpers ─────────────────────────────────
function shortAddr(addr: string): string {
  if (!addr || addr.length < 10) return addr;
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function toLocale(wei: string): string {
  if (!wei) return "—";
  const num = parseFloat(wei) / 1e18;
  if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(2)}M`;
  if (num >= 1_000) return num.toLocaleString(undefined, { maximumFractionDigits: 0 });
  return num.toFixed(4);
}

function formatDate(ts: string): string {
  if (!ts || ts === "0") return "—";
  return new Date(Number(ts) * 1000).toLocaleString();
}

function statusLabel(s: string): string {
  const map: Record<string, string> = {
    LOCKED: "锁定中",
    UNLOCKING: "解锁中",
    UNLOCKED: "已解锁",
    WITHDRAWN: "已提取",
  };
  return map[s] ?? s;
}
</script>

<template>
  <div>
    <!-- ══ Hero ══ -->
    <div class="hero">
      <div>
        <h3>锁仓管理</h3>
        <p>管理 PANGU2 锁仓奖励池、覆盖率和用户仓位。充值奖励和设置速率需要 SUPER_ADMIN 权限。</p>
      </div>
      <div class="hero-side">
        <strong v-if="staking.coverage?.coverageRatioPercent">{{ staking.coverage.coverageRatioPercent }}</strong>
        <strong v-else>—</strong>
        <small>偿付率</small>
        <small v-if="staking.dataStatus !== 'LIVE'" class="mock-badge">MOCK DATA</small>
      </div>
    </div>

    <!-- ══ A) KPI 卡片 ══ -->
    <div class="kpi-grid">
      <div class="kpi">
        <div class="kpi-head"><span>总锁仓量</span></div>
        <strong>{{ staking.coverage?.totalStakedFormatted ?? "—" }}</strong>
        <footer>PANGU2</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>奖励速率</span></div>
        <strong>{{ staking.coverage?.rewardRateFormatted ?? "—" }}</strong>
        <footer>wei/s</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>奖励储备池</span></div>
        <strong>{{ staking.coverage?.rewardReserveFormatted ?? "—" }}</strong>
        <footer>PANGU2</footer>
      </div>
      <div class="kpi">
        <div class="kpi-head"><span>偿付率</span></div>
        <strong>{{ staking.coverage?.coverageRatioPercent ?? "—" }}</strong>
        <footer>{{ staking.coverage?.coverageRatioPercent ? "储备/应付" : "加载中" }}</footer>
      </div>
    </div>

    <!-- ══ B) 管理操作区 ══ -->
    <div class="section-head"><h3>管理操作</h3></div>
    <div class="layout-2">
      <!-- 充值奖励池 -->
      <div class="card">
        <div class="card-head">
          <h4>充值奖励池</h4>
          <span class="tag" :class="staking.coverage ? 'ok' : 'warning'">
            {{ staking.coverage ? "SUPER_ADMIN" : "未加载" }}
          </span>
        </div>
        <div class="card-body">
          <div class="field">
            <label>Token 数量 (PANGU2)</label>
            <div class="input-row">
              <input v-model="fundAmount" type="number" min="0" step="1" placeholder="100000" />
              <span class="input-unit">PANGU2</span>
            </div>
          </div>
          <button
            class="action-btn"
            :disabled="staking.fundLoading || !fundAmount"
            @click="staking.requestFundRewards(fundAmount)"
          >
            {{ staking.fundLoading ? "充值中..." : "充值奖励池" }}
          </button>
          <div v-if="staking.fundSuccess" class="msg ok">{{ staking.fundSuccess }}</div>
          <div v-if="staking.fundError" class="msg err">{{ staking.fundError }}</div>
        </div>
      </div>

      <!-- 设置奖励速率 -->
      <div class="card">
        <div class="card-head">
          <h4>设置奖励速率</h4>
          <span class="tag" :class="staking.coverage ? 'ok' : 'warning'">
            {{ staking.coverage ? "SUPER_ADMIN" : "未加载" }}
          </span>
        </div>
        <div class="card-body">
          <div class="field">
            <label>每秒奖励 (wei)</label>
            <div class="input-row">
              <input v-model="rewardRateInput" type="number" min="0" step="1" placeholder="11574074074074" />
              <span class="input-unit">wei/s</span>
            </div>
            <small v-if="rewardRateInput" style="margin-top:4px; color: var(--muted)">
              ≈ {{ toLocale(rewardRateInput) }} token/秒 · {{ (parseFloat(rewardRateInput || "0") * 86400 / 1e18).toFixed(4) }} token/天
            </small>
          </div>
          <button
            class="action-btn"
            :disabled="staking.rateLoading || !rewardRateInput"
            @click="staking.requestSetRewardRate(rewardRateInput)"
          >
            {{ staking.rateLoading ? "设置中..." : "设置速率" }}
          </button>
          <div v-if="staking.rateSuccess" class="msg ok">{{ staking.rateSuccess }}</div>
          <div v-if="staking.rateError" class="msg err">{{ staking.rateError }}</div>
        </div>
      </div>
    </div>

    <!-- ══ Confirm Modal ══ -->
    <Transition name="modal">
      <div v-if="staking.confirmModal" class="moverlay" @click.self="staking.cancelAction()">
        <div class="mpanel">
          <b>{{ staking.confirmModal.title }}</b>
          <p style="white-space:pre-line">{{ staking.confirmModal.summary }}</p>
          <div class="mbtns">
            <button class="btn danger" @click="staking.confirmAction()">确认执行</button>
            <button class="btn sec" @click="staking.cancelAction()">取消</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ══ C) 用户仓位查询 ══ -->
    <div class="section-head"><h3>仓位查询</h3></div>
    <div class="card">
      <div class="card-body">
        <div class="search-bar">
          <input
            v-model="staking.searchAddress"
            type="text"
            placeholder="输入钱包地址 0x..."
            @keyup.enter="staking.searchPositions(staking.searchAddress)"
          />
          <button class="btn sec" @click="staking.searchPositions(staking.searchAddress)">查询</button>
        </div>

        <!-- Loading -->
        <div v-if="staking.positionsLoading" class="loading">查询中...</div>

        <!-- Results -->
        <div v-else-if="staking.positions.length > 0" class="pos-list">
          <div
            v-for="pos in staking.positions"
            :key="pos.positionId"
            class="pos-item"
          >
            <div class="pos-summary" @click="toggleExpand(pos.positionId)">
              <span class="pos-id">#{{ pos.positionId }}</span>
              <span class="pos-amount">{{ pos.amountFormatted || toLocale(pos.amount) }} P2</span>
              <span
                class="tag"
                :class="{
                  ok: pos.status === 'LOCKED',
                  warning: pos.status === 'UNLOCKING',
                  gold: pos.status === 'UNLOCKED',
                  muted: pos.status === 'WITHDRAWN',
                }"
              >
                {{ statusLabel(pos.status) }}
              </span>
              <span class="toggle-icon">{{ expandedPosition === pos.positionId ? '▾' : '▸' }}</span>
            </div>
            <!-- Expand detail -->
            <div v-if="expandedPosition === pos.positionId" class="pos-detail">
              <div class="detail-row"><span>仓位ID</span><b>{{ pos.positionId }}</b></div>
              <div class="detail-row"><span>持有者</span><b class="mono">{{ shortAddr(pos.owner) }}</b></div>
              <div class="detail-row"><span>锁仓金额</span><b>{{ toLocale(pos.amount) }} P2</b></div>
              <div class="detail-row"><span>锁仓时间</span><b>{{ formatDate(pos.lockedAt) }}</b></div>
              <div class="detail-row"><span>解锁时间</span><b>{{ formatDate(pos.unlockAt) }}</b></div>
              <div class="detail-row"><span>预估收益</span><b>{{ pos.estimatedRewardFormatted || toLocale(pos.estimatedReward) }} P2</b></div>
              <div class="detail-row"><span>状态</span><b>{{ statusLabel(pos.status) }}</b></div>
            </div>
          </div>
        </div>
        <!-- Empty -->
        <div v-else-if="staking.searchAddress && !staking.positionsLoading" class="empty">
          未找到该地址的仓位
        </div>
        <div v-else class="empty-hint">
          输入钱包地址查询锁仓仓位
        </div>
      </div>
    </div>

    <!-- ══ D) 系统状态 ══ -->
    <div class="section-head"><h3>锁仓系统状态</h3></div>
    <div v-if="staking.status" class="card">
      <div class="card-body">
        <div class="status-grid">
          <div class="status-item"><span>奖励Token</span><b class="mono">{{ shortAddr(staking.status.rewardToken) }}</b></div>
          <div class="status-item"><span>锁仓Token</span><b class="mono">{{ shortAddr(staking.status.stakingToken) }}</b></div>
          <div class="status-item"><span>当前速率</span><b>{{ staking.status.rewardRate }}</b></div>
          <div class="status-item"><span>总锁仓</span><b>{{ staking.status.totalSupplyFormatted }} P2</b></div>
          <div class="status-item"><span>最后更新区块</span><b>#{{ staking.status.lastUpdateBlock }}</b></div>
          <div class="status-item"><span>奖励周期截止</span><b>{{ formatDate(staking.status.periodFinish) }}</b></div>
        </div>
      </div>
    </div>
    <div v-else class="card" style="text-align:center; padding:20px; color:var(--muted)">
      {{ staking.statusLoading ? "加载中..." : "无法加载锁仓系统状态" }}
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
.mock-badge { color: var(--orange); font-size: 8px; font-weight: 900; background: rgba(243,163,75,.1); padding: 1px 5px; border-radius: 4px; }

.kpi-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-top: 12px; }
.kpi { border: 1px solid var(--line); background: var(--panel); padding: 16px; }
.kpi-head { display: flex; justify-content: space-between; color: var(--muted); font-size: 11px; }
.kpi strong { display: block; font-size: 23px; margin-top: 9px; font-weight: 720; }
.kpi footer { display: flex; justify-content: space-between; margin-top: 6px; color: var(--muted); font-size: 10px; }

.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }

.layout-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }

.card-head { display: flex; justify-content: space-between; align-items: center; padding: 14px; border-bottom: 1px solid rgba(255,255,255,.04); }
.card-head h4 { font-size: 13px; }
.card-body { padding: 14px; }

.field { margin-bottom: 12px; }
.field label { display: block; color: var(--muted); font-size: 11px; margin-bottom: 5px; }
.input-row { display: flex; gap: 8px; align-items: center; }
.input-row input { flex: 1; min-width: 0; height: 40px; padding: 0 12px; border: 1px solid var(--line); background: var(--panel2); color: var(--text); font-size: 13px; outline: 0; border-radius: 8px; }
.input-row input:focus { border-color: rgba(214,173,95,.45); }
.input-unit { color: var(--muted); font-size: 12px; white-space: nowrap; }
.field small { display: block; color: var(--muted); font-size: 10px; }

.action-btn { width: 100%; height: 42px; border: 0; background: linear-gradient(135deg, var(--gold2), var(--gold)); color: #15120c; font-size: 13px; font-weight: 750; cursor: pointer; border-radius: 8px; }
.action-btn:disabled { opacity: .45; cursor: not-allowed; }

.msg { padding: 8px 12px; margin-top: 8px; font-size: 11px; border-radius: 6px; }
.msg.ok { background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); color: var(--green); }
.msg.err { background: rgba(255,116,125,.08); border: 1px solid rgba(255,116,125,.18); color: var(--red); }

/* Search bar */
.search-bar { display: flex; gap: 8px; margin-bottom: 14px; }
.search-bar input { flex: 1; min-width: 0; height: 42px; padding: 0 14px; border: 1px solid var(--line); background: var(--panel2); color: var(--text); font-size: 13px; outline: 0; border-radius: 8px; font-family: monospace; }
.search-bar input:focus { border-color: rgba(214,173,95,.45); }

/* Position list */
.pos-list { display: flex; flex-direction: column; }
.pos-item { border: 1px solid rgba(255,255,255,.04); border-radius: 10px; margin-bottom: 6px; overflow: hidden; }
.pos-summary { display: grid; grid-template-columns: 60px 1fr 80px 24px; gap: 12px; align-items: center; padding: 12px 14px; cursor: pointer; transition: background .15s; }
.pos-summary:hover { background: rgba(255,255,255,.02); }
.pos-id { font-family: monospace; font-size: 11px; color: var(--gold2); }
.pos-amount { font-size: 13px; font-weight: 650; }
.toggle-icon { text-align: right; color: var(--muted); font-size: 13px; }
.pos-detail { padding: 12px 14px; border-top: 1px solid rgba(255,255,255,.05); background: rgba(0,0,0,.12); }
.detail-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; font-size: 11px; }
.detail-row+.detail-row { border-top: 1px solid rgba(255,255,255,.03); }
.detail-row span { color: var(--muted); }
.detail-row b { font-size: 11px; }
.mono { font-family: monospace; font-size: 10px !important; }

/* Status grid */
.status-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
.status-item { padding: 12px; border: 1px solid rgba(255,255,255,.04); border-radius: 8px; background: rgba(255,255,255,.01); }
.status-item span { display: block; color: var(--muted); font-size: 10px; margin-bottom: 4px; }
.status-item b { display: block; font-size: 13px; }

.loading { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }
.empty { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }
.empty-hint { padding: 20px; text-align: center; color: var(--muted); font-size: 11px; }

/* Tags */
.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }
.tag.gold { color: var(--gold2); background: rgba(216,170,81,.08); border: 1px solid rgba(216,170,81,.18); }
.tag.muted { color: var(--muted); background: rgba(146,152,165,.08); border: 1px solid rgba(146,152,165,.18); }
.tag.danger { color: var(--red); background: rgba(255,116,125,.08); border: 1px solid rgba(255,116,125,.18); }

/* Buttons */
.btn { height: 36px; border: 0; padding: 0 16px; border-radius: 8px; font-weight: 700; font-size: 12px; cursor: pointer; }
.btn.sec { background: var(--panel2); color: var(--text); border: 1px solid var(--line); }
.btn.danger { background: rgba(255,116,125,.15); color: var(--red); border: 1px solid rgba(255,116,125,.25); }

/* Modal */
.moverlay { position: fixed; inset: 0; z-index: 100; background: rgba(0,0,0,.6); display: grid; place-items: center; }
.mpanel { width: min(90%, 440px); background: var(--panel); border: 1px solid var(--line); padding: 24px; border-radius: 14px; }
.mpanel b { display: block; font-size: 16px; margin-bottom: 12px; }
.mpanel p { font-size: 12px; color: var(--muted); line-height: 1.6; margin-bottom: 18px; }
.mpanel code { background: var(--panel2); padding: 2px 6px; border-radius: 4px; font-size: 11px; }
.mbtns { display: flex; gap: 10px; }
.mbtns .btn { flex: 1; }

.modal-enter-active, .modal-leave-active { transition: opacity .2s; }
.modal-enter-from, .modal-leave-to { opacity: 0; }

@media (max-width: 1180px) { .kpi-grid { grid-template-columns: repeat(2, 1fr); } .layout-2 { grid-template-columns: 1fr; } .status-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 520px) { .kpi-grid { grid-template-columns: 1fr; } .status-grid { grid-template-columns: 1fr; } }
</style>
