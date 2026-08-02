<script setup lang="ts">
import { ref } from "vue";
import { useWalletStore } from "@/stores/useWallet";
import { useDataStatusStore } from "@/stores/data/useDataStatus";
import BottomNav from "@/components/BottomNav.vue";
import ConnectSheet from "@/components/ConnectSheet.vue";
import NetworkBanner from "@/components/NetworkBanner.vue";
import DataStatusBanner from "@/components/common/DataStatusBanner.vue";
import ErrorBoundary from "@/components/common/ErrorBoundary.vue";

const dataStatus = useDataStatusStore();

const wallet = useWalletStore();
const connectSheetRef = ref<InstanceType<typeof ConnectSheet> | null>(null);

function handleWalletBtnClick(): void {
  if (wallet.isConnected) return;
  // Open the ConnectSheet directly for a better UX
  connectSheetRef.value?.open();
}

function walletBtnLabel(): string {
  if (wallet.isConnecting) return "连接中...";
  if (wallet.hasError) return "连接失败";
  if (wallet.isConnected) return wallet.shortAddress;
  return "连接钱包";
}

function walletBtnClass(): Record<string, boolean> {
  return {
    connected: wallet.isConnected,
    connecting: wallet.isConnecting,
    error: wallet.hasError,
  };
}
</script>

<template>
  <div class="app">
    <header class="topbar">
      <div class="brand">
        <div class="logo">盘</div>
        <div>
          <b>PANGU2</b>
          <small>{{ wallet.isConnected ? `${wallet.chainName} · ${wallet.chainId}` : '未连接' }}</small>
        </div>
      </div>
      <div class="top-actions">
        <button
          class="wallet-btn"
          :class="walletBtnClass()"
          @click="handleWalletBtnClick"
          :disabled="wallet.isConnecting"
        >
          <span v-if="wallet.isConnecting" class="btn-spinner" />
          {{ walletBtnLabel() }}
        </button>
      </div>
    </header>

    <!-- Dynamic data status banner (replaces hardcoded MOCK DATA badge) -->
    <DataStatusBanner
      :data-status="dataStatus.status"
      :block-number="dataStatus.blockNumber"
      :age-formatted="dataStatus.ageFormatted"
    />

    <!-- Network mismatch warning -->
    <NetworkBanner />

    <main>
      <ErrorBoundary fallback-message="页面渲染失败，请刷新重试。">
        <router-view />
      </ErrorBoundary>
    </main>

    <BottomNav />

    <!-- Wallet connect sheet (slide-up bottom sheet) -->
    <ConnectSheet ref="connectSheetRef" />
  </div>
</template>

<style scoped>
.app {
  width: 100%;
  max-width: 430px;
  min-height: 100vh;
  margin: 0 auto;
  position: relative;
  overflow-x: hidden;
  background: radial-gradient(circle at 95% 0, rgba(216,170,81,.11), transparent 29%), var(--bg);
}

.topbar {
  position: sticky;
  top: 0;
  z-index: 40;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: calc(11px + env(safe-area-inset-top)) 14px 10px;
  background: rgba(8,10,14,.93);
  backdrop-filter: blur(18px);
  border-bottom: 1px solid rgba(255,255,255,.04);
}

.brand {
  display: flex;
  gap: 9px;
  align-items: center;
}

.logo {
  width: 36px;
  height: 36px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  font-weight: 950;
  color: var(--gold2);
  border: 1px solid rgba(216,170,81,.48);
  background: rgba(216,170,81,.08);
}

.brand b { font-size: 15px; }
.brand small { display: block; font-size: 9px; color: var(--muted); margin-top: 2px; }

.top-actions { display: flex; gap: 7px; align-items: center; }

.wallet-btn {
  height: 36px;
  border: 0;
  background: var(--gold);
  color: #181108;
  font-size: 11px;
  font-weight: 900;
  padding: 0 11px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  gap: 5px;
  transition: background 0.2s, color 0.2s;
}

.wallet-btn.connected {
  background: var(--panel);
  color: var(--gold2);
  border: 1px solid rgba(216,170,81,.4);
}

.wallet-btn.connecting {
  background: var(--panel);
  color: var(--muted);
  border: 1px solid var(--line);
}

.wallet-btn.error {
  background: rgba(255,116,125,.12);
  color: var(--red);
  border: 1px solid rgba(255,116,125,.3);
}

.wallet-btn:disabled {
  cursor: wait;
}

.btn-spinner {
  display: inline-block;
  width: 12px;
  height: 12px;
  border: 2px solid rgba(255,255,255,.25);
  border-top-color: var(--muted);
  border-radius: 50%;
  animation: btn-spin 0.7s linear infinite;
}

@keyframes btn-spin {
  to { transform: rotate(360deg); }
}

main {
  padding: 14px 14px calc(70px + 22px + env(safe-area-inset-bottom));
}
</style>
