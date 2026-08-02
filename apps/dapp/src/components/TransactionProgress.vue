<!--
  PANGU2 DApp — TransactionProgress
  Full lifecycle UI: pending bar, confirm overlay, tx links.
-->
<script setup lang="ts">
import { computed } from "vue";
import type { TxPhase } from "@/features/transactions/useTransaction";
import { ApprovalState, ChainTxState } from "@pangu2/api-types";

const props = withDefaults(
  defineProps<{
    phase: TxPhase;
    chainTxState: ChainTxState;
    approvalState?: ApprovalState;
    sellTxHash?: `0x${string}` | null;
    error?: string | null;
    errorRecoverable?: boolean;
    blockNumber?: string | null;
  }>(),
  {
    approvalState: ApprovalState.NOT_REQUIRED,
    sellTxHash: null,
    error: null,
    errorRecoverable: false,
    blockNumber: null,
  },
);

const emit = defineEmits<{ close: []; recover: [] }>();

const show = computed(() => props.phase !== "NOT_STARTED");

const phaseLabels: Partial<Record<TxPhase, string>> = {
  FETCHING_QUOTE: "Fetching quote...",
  APPROVAL_CHECK: "Checking approval...",
  APPROVAL_REQUIRED: "Approval needed",
  APPROVAL_SIGNING: "Sign approval...",
  APPROVAL_SUBMITTED: "Approval submitted",
  APPROVAL_CONFIRMING: "Confirming approval...",
  APPROVAL_DONE: "Approval confirmed",
  SIGNING: "Sign transaction...",
  SUBMITTING: "Broadcasting...",
  PENDING: "Pending confirmation...",
  CONFIRMED: "Confirmed",
  FAILED: "Failed",
  REJECTED: "Rejected",
};

const label = computed(() => phaseLabels[props.phase] ?? props.phase);

const barPct = computed(() => {
  const m: Partial<Record<TxPhase, string>> = {
    FETCHING_QUOTE: "15%", APPROVAL_SIGNING: "40%", APPROVAL_SUBMITTED: "55%",
    SIGNING: "70%", SUBMITTING: "85%", PENDING: "92%", CONFIRMED: "100%",
  };
  return m[props.phase] ?? "10%";
});

const hashShort = computed(() => {
  if (!props.sellTxHash) return null;
  return `${props.sellTxHash.slice(0, 10)}...${props.sellTxHash.slice(-8)}`;
});

const link = computed(() =>
  props.sellTxHash ? `https://testnet.bscscan.com/tx/${props.sellTxHash}` : null,
);
</script>

<template>
  <Transition name="tx-fade">
    <div v-if="show" class="tx-overlay">
      <div class="tx-panel">
        <button v-if="phase==='CONFIRMED'||phase==='FAILED'||phase==='REJECTED'"
          class="tx-close" @click="emit('close')">✕</button>
        <div class="tx-header">
          <span class="tx-status" :class="{ok:phase==='CONFIRMED',danger:phase==='FAILED',warn:phase==='REJECTED'}">{{ label }}</span>
        </div>
        <div v-if="phase!=='CONFIRMED'&&phase!=='FAILED'&&phase!=='REJECTED'" class="bar-wrap">
          <div class="bar anim" :style="{width:barPct}" />
        </div>
        <div v-if="sellTxHash" class="tx-info">
          <span>Tx:</span>
          <a :href="link??'#'" target="_blank" rel="noopener" class="link">{{ hashShort }}</a>
        </div>
        <div v-if="blockNumber" class="tx-info">Block: #{{ blockNumber }}</div>
        <div v-if="error" class="tx-err" :class="{rec:errorRecoverable}">{{ error }}</div>
        <div class="tx-actions" v-if="errorRecoverable||phase==='APPROVAL_REQUIRED'">
          <button class="btn" :class="phase==='APPROVAL_REQUIRED'?'pri':'warn'" @click="emit('recover')">
            {{ phase==='APPROVAL_REQUIRED'?'Approve':'Retry' }}</button>
          <button class="btn sec" @click="emit('close')">Cancel</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.tx-overlay{position:fixed;inset:0;z-index:100;background:rgba(0,0,0,.72);display:flex;align-items:flex-end;justify-content:center;padding:20px}
.tx-fade-enter-active,.tx-fade-leave-active{transition:opacity .25s}
.tx-fade-enter-from,.tx-fade-leave-to{opacity:0}
.tx-panel{width:100%;max-width:430px;background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:20px;position:relative}
.tx-close{position:absolute;top:10px;right:12px;border:0;background:none;color:var(--muted);font-size:16px;cursor:pointer}
.tx-header{margin-bottom:14px;text-align:center}
.tx-status{font-weight:900;font-size:15px;color:var(--gold2)}
.tx-status.ok{color:var(--green)} .tx-status.danger{color:var(--red)} .tx-status.warn{color:var(--orange)}
.bar-wrap{height:4px;background:rgba(255,255,255,.06);border-radius:2px;margin-bottom:14px;overflow:hidden}
.bar{height:100%;background:linear-gradient(90deg,var(--gold2),var(--gold));border-radius:2px;transition:width .6s}
.bar.anim{animation:bpulse 1.2s infinite} @keyframes bpulse{0%,100%{opacity:1}50%{opacity:.5}}
.tx-info{text-align:center;font-size:10px;color:var(--muted);margin-bottom:6px}
.link{color:var(--gold2);font-family:monospace;font-size:10px;text-decoration:none}
.tx-err{padding:10px;border-radius:8px;background:rgba(255,116,125,.06);border:1px solid rgba(255,116,125,.15);color:var(--red);font-size:11px;text-align:center;margin-bottom:12px}
.tx-err.rec{background:rgba(243,163,75,.06);border-color:rgba(243,163,75,.15);color:var(--orange)}
.tx-actions{display:flex;gap:8px;justify-content:center}
.btn{height:38px;padding:0 20px;border:0;border-radius:10px;font-weight:800;font-size:12px;cursor:pointer}
.btn.pri{background:linear-gradient(135deg,var(--gold2),var(--gold));color:#171108}
.btn.warn{background:var(--orange);color:#171108}
.btn.sec{background:rgba(255,255,255,.05);color:var(--muted);border:1px solid var(--line)}
</style>
