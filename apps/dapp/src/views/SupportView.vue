<!--
  PANGU2 DApp — SupportView (托底池)
  对接 /buybacks 和 /locker/batches API
  硬规则:
  - SupportPool 只读展示，无提现入口
  - 显示回购批次和锁仓状态
  - 公开触发回购按钮（Mock阶段模拟）
-->
<script setup lang="ts">
import { computed } from "vue";
import { useSupport } from "@/features/support/useSupport";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ErrorState from "@/components/common/ErrorState.vue";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";

const { buybacks, locker, isLoading, isMockData, formatTokens, formatBnb, timeAgo } =
  useSupport();

// ── 派生 ────────────────────────────────────

const buybackMeta = computed(() => buybacks.state.value.meta);
const buybackItems = computed(() => buybacks.state.value.data ?? []);
const lockerItems = computed(() => locker.state.value.data ?? []);

// Mock 池统计（后续从 API 获取）
const mockPendingTax = "2.84M P2";
const mockPoolBalance = "18.42 BNB";
const mockCumulativeBuy = "42.8M P2";
const mockCumulativeBurn = "8.21M P2";

function handleTriggerBuyback(): void {
  // Mock: 模拟公开触发回购（F07 实现真正链上调用）
  alert("Mock: 公开触发回购（F07 实现真正链上调用）");
}
</script>

<template>
  <div>
    <div class="page-title">
      <h1>托底池</h1>
      <p>卖出税费先累计为PANGU2，达到门槛后兑换为BNB，再分批回购并锁仓365天。</p>
    </div>

    <DataStatusBanner
      v-if="buybackMeta"
      :data-status="buybackMeta.data_status"
      :block-number="buybackMeta.block_number"
    />

    <!-- 池统计 -->
    <div class="detail-grid">
      <div class="detail-stat"><span>待兑换税费</span><b>{{ mockPendingTax }}</b></div>
      <div class="detail-stat"><span>托底池余额</span><b>{{ mockPoolBalance }}</b></div>
      <div class="detail-stat"><span>累计回购</span><b>{{ mockCumulativeBuy }}</b></div>
      <div class="detail-stat"><span>累计销毁</span><b>{{ mockCumulativeBurn }}</b></div>
    </div>

    <!-- 资金流程 -->
    <div class="section-head"><h2>资金流程</h2></div>
    <div class="card">
      <div class="flow">
        <div class="flow-box">卖出税费 P2</div><div class="flow-arrow">→</div>
        <div class="flow-box">兑换 BNB</div><div class="flow-arrow">→</div>
        <div class="flow-box">0.01 BNB 回购</div><div class="flow-arrow">→</div>
        <div class="flow-box">锁仓365天</div>
      </div>
    </div>

    <!-- 下一次可执行 -->
    <div class="section-head"><h2>公开触发回购</h2></div>
    <div class="card">
      <div class="pool-pulse">
        <div>
          <div class="sub">最小间隔60秒 · 0.01 BNB/次</div>
          <div class="sub">任何人可公开触发，回购后锁仓365天</div>
        </div>
        <div class="pool-right"><b>0.01 BNB</b><span>约回购4,607 P2</span></div>
      </div>
      <button class="full-btn" style="margin-top:13px" @click="handleTriggerBuyback">
        公开触发回购
      </button>
    </div>

    <!-- 最近回购 -->
    <div class="section-head"><h2>最近回购</h2></div>
    <LoadingSpinner v-if="isLoading && buybackItems.length === 0" size="sm" label="加载回购记录..." />
    <ErrorState
      v-if="buybacks.state.value.error && !isLoading"
      :message="buybacks.state.value.error ?? '获取失败'"
      :retryable="buybacks.state.value.errorRetryable"
      compact
      @retry="buybacks.execute()"
    />
    <div v-else class="card">
      <div v-if="buybackItems.length === 0 && !isLoading" class="empty-hint">
        暂无回购记录
      </div>
      <div
        v-for="bb in buybackItems"
        :key="bb.batch_id"
        class="timeline-item"
      >
        <div class="timeline-dot">✓</div>
        <div class="timeline-copy">
          <b>回购 {{ formatTokens(bb.tokens_raw) }}</b>
          <span>{{ formatBnb(bb.amount_bnb_wei) }} · 批次#{{ bb.batch_id }} · {{ timeAgo(bb.timestamp) }}</span>
        </div>
      </div>

      <!-- 锁仓批次 -->
      <div v-if="lockerItems.length > 0" style="margin-top:8px; padding-top:8px; border-top:1px solid var(--line)">
        <div class="section-head"><h2>锁仓批次</h2></div>
        <div v-for="lk in lockerItems" :key="lk.batch_id" class="timeline-item">
          <div class="timeline-dot lock">🔒</div>
          <div class="timeline-copy">
            <b>{{ formatTokens(lk.tokens_raw) }}</b>
            <span>锁定至 {{ new Date(lk.locked_until).toLocaleDateString() }} · 批次#{{ lk.batch_id }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-title { margin: 4px 2px 14px; }
.page-title h1 { font-size: 23px; }
.page-title p { font-size: 10px; color: var(--muted); margin-top: 6px; }

.detail-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.detail-stat { padding: 11px; border-radius: 13px; border: 1px solid rgba(255,255,255,.045); background: rgba(255,255,255,.025); }
.detail-stat span { display: block; color: var(--muted); font-size: 8px; }
.detail-stat b { display: block; margin-top: 5px; font-size: 13px; }

.section-head { margin: 18px 2px 9px; }
.section-head h2 { font-size: 14px; }

.flow { display: flex; align-items: center; gap: 7px; overflow-x: auto; padding: 4px 0; }
.flow-box { flex: 0 0 auto; padding: 9px 10px; border-radius: 12px; border: 1px solid var(--line); background: var(--panel2); font-size: 9px; }
.flow-arrow { color: var(--gold); }

.pool-pulse { display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: center; }
.countdown { font-size: 27px; font-weight: 950; margin-top: 3px; }
.sub { color: var(--muted); font-size: 10px; line-height: 1.5; }
.pool-right { text-align: right; }
.pool-right b { font-size: 13px; color: var(--gold2); }
.pool-right span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }

.progress { height: 6px; background: #252932; border-radius: 99px; overflow: hidden; margin-top: 10px; }
.progress i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), var(--gold2)); border-radius: inherit; transition: .3s; }

.timeline-item { display: flex; gap: 10px; padding: 10px 0; }
.timeline-item+.timeline-item { border-top: 1px solid rgba(255,255,255,.05); }
.timeline-dot { width: 30px; height: 30px; border-radius: 10px; background: rgba(67,207,139,.08); color: var(--green); display: grid; place-items: center; }
.timeline-dot.lock { background: rgba(216,170,81,.08); }
.timeline-copy b { display: block; font-size: 10px; }
.timeline-copy span { display: block; color: var(--muted); font-size: 8px; margin-top: 3px; }

.empty-hint { padding: 20px; text-align: center; color: var(--muted); font-size: 11px; }

.mock-footer { display: flex; gap: 8px; align-items: center; justify-content: center; }
.mock-footer small { color: var(--muted); font-size: 9px; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }
</style>
