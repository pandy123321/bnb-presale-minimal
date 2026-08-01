<!-- ═══════════════════════════════════════════
  PANGU2 DApp — NetworkBanner
  Persistent banner when connected to an unsupported chain.
  States: UNSUPPORTED (warning + switch btn) → SWITCHING (spinner) → ERROR (retry)
  Hidden when SUPPORTED / UNKNOWN / DISCONNECTED.
  ═══════════════════════════════════════════ -->

<script setup lang="ts">
import { useWalletStore } from "@/stores/useWallet";
import { SUPPORTED_CHAIN_IDS, CHAIN_LABELS } from "@/features/wallet/config";

const wallet = useWalletStore();

function supportedChainNames(): string {
  return SUPPORTED_CHAIN_IDS
    .map((id) => CHAIN_LABELS[id]?.name ?? `Chain ${id}`)
    .join(" / ");
}
</script>

<template>
  <div
    v-if="wallet.isNetworkUnsupported || wallet.isSwitchingNetwork || (wallet.isNetworkUnsupported && wallet.hasError)"
    class="network-banner"
  >
    <div class="nb-inner">
      <div class="nb-icon">
        <template v-if="wallet.isSwitchingNetwork">
          <span class="nb-spinner" />
        </template>
        <template v-else>
          ⚠
        </template>
      </div>

      <div class="nb-text">
        <template v-if="wallet.isSwitchingNetwork">
          <b>切换网络中...</b>
          <small>请在钱包中确认网络切换</small>
        </template>
        <template v-else-if="wallet.hasError && wallet.isNetworkUnsupported">
          <b>网络切换失败</b>
          <small>{{ wallet.error }}</small>
        </template>
        <template v-else>
          <b>不支持的网络</b>
          <small>当前: {{ wallet.chainName }} ({{ wallet.chainId }}). 请切换到 {{ supportedChainNames() }}</small>
        </template>
      </div>

      <div class="nb-action">
        <template v-if="wallet.isSwitchingNetwork">
          <button class="nb-btn" disabled>
            <span class="nb-spinner sm" /> 等待中
          </button>
        </template>
        <template v-else-if="wallet.hasError">
          <button class="nb-btn" @click="wallet.switchToSupportedChain()">
            重试
          </button>
        </template>
        <template v-else>
          <button class="nb-btn" @click="wallet.switchToSupportedChain()">
            切换网络
          </button>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.network-banner {
  background: linear-gradient(135deg, rgba(243, 163, 75, 0.13), rgba(243, 163, 75, 0.06));
  border-bottom: 1px solid rgba(243, 163, 75, 0.18);
  padding: 10px 14px;
}

.nb-inner {
  display: flex;
  align-items: center;
  gap: 10px;
}

.nb-icon {
  font-size: 18px;
  flex-shrink: 0;
  width: 24px;
  display: grid;
  place-items: center;
}

.nb-text {
  flex: 1;
  min-width: 0;
}

.nb-text b {
  display: block;
  font-size: 12px;
  color: var(--orange);
}

.nb-text small {
  display: block;
  font-size: 10px;
  color: var(--muted);
  margin-top: 1px;
  line-height: 1.4;
}

.nb-action {
  flex-shrink: 0;
}

.nb-btn {
  height: 30px;
  padding: 0 12px;
  border: 1px solid rgba(243, 163, 75, 0.35);
  background: rgba(243, 163, 75, 0.12);
  color: var(--orange);
  font-size: 11px;
  font-weight: 700;
  border-radius: 10px;
  white-space: nowrap;
  display: flex;
  align-items: center;
  gap: 5px;
}

.nb-btn:hover {
  background: rgba(243, 163, 75, 0.2);
}

.nb-btn:disabled {
  opacity: 0.5;
}

.nb-spinner {
  display: inline-block;
  width: 14px;
  height: 14px;
  border: 2px solid rgba(243, 163, 75, 0.3);
  border-top-color: var(--orange);
  border-radius: 50%;
  animation: nb-spin 0.7s linear infinite;
}

.nb-spinner.sm {
  width: 11px;
  height: 11px;
  border-width: 1.5px;
}

@keyframes nb-spin {
  to { transform: rotate(360deg); }
}
</style>
