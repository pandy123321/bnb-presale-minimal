<!-- ═══════════════════════════════════════════
  PANGU2 DApp — ConnectSheet
  Slide-up bottom sheet for wallet connection.
  States: DISCONNECTED (entry btn) → CONNECTING (spinner) → ERROR (retry)
  ═══════════════════════════════════════════ -->

<script setup lang="ts">
import { ref, watch } from "vue";
import { useWalletStore } from "@/stores/useWallet";

const wallet = useWalletStore();

const emit = defineEmits<{
  (e: "close"): void;
}>();

const visible = ref(false);

function open(): void {
  visible.value = true;
}

function close(): void {
  visible.value = false;
  wallet.clearError();
}

function handleConnect(): void {
  wallet.connect();
}

function handleRetry(): void {
  wallet.clearError();
  wallet.connect();
}

// Open when store triggers connection from legacy API
watch(
  () => wallet.isConnecting,
  (val) => {
    if (val) visible.value = true;
  },
);

// Auto-close when connected
watch(
  () => wallet.isConnected,
  (val) => {
    if (val) visible.value = false;
  },
);

defineExpose({ open, close });
</script>

<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div v-if="visible" class="sheet-overlay" @click.self="close">
        <div class="sheet-panel">
          <div class="sheet-handle" />
          <div class="sheet-header">
            <h3>连接钱包</h3>
            <button class="sheet-close" @click="close" aria-label="Close">✕</button>
          </div>

          <!-- DISCONNECTED / CONNECTING / ERROR states -->
          <template v-if="!wallet.isConnected">
            <p class="sheet-desc">
              <template v-if="wallet.isConnecting">
                请在钱包中确认连接请求...
              </template>
              <template v-else-if="wallet.hasError">
                {{ wallet.error }}
              </template>
              <template v-else>
                连接 MetaMask 或兼容钱包以查看您的链上资产。
              </template>
            </p>

            <!-- CONNECTING: spinner -->
            <div v-if="wallet.isConnecting" class="sheet-loading">
              <div class="spinner" />
              <span>等待钱包确认...</span>
            </div>

            <!-- ERROR: retry + dismiss -->
            <div v-else-if="wallet.hasError" class="sheet-error">
              <button class="primary-btn" style="width:100%; margin-bottom:8px" @click="handleRetry">
                重试连接
              </button>
              <button class="secondary-btn" style="width:100%" @click="close">
                取消
              </button>
            </div>

            <!-- DISCONNECTED: connect button -->
            <div v-else class="sheet-wallets">
              <button class="wallet-option" @click="handleConnect">
                <span class="wallet-option-icon">🦊</span>
                <div class="wallet-option-info">
                  <b>MetaMask</b>
                  <small>浏览器扩展钱包</small>
                </div>
                <span class="wallet-option-arrow">›</span>
              </button>

              <button class="wallet-option" @click="handleConnect">
                <span class="wallet-option-icon">🌐</span>
                <div class="wallet-option-info">
                  <b>Injected Wallet</b>
                  <small>Rabby / Trust / OKX / Coinbase</small>
                </div>
                <span class="wallet-option-arrow">›</span>
              </button>
            </div>

            <p class="sheet-footer-text">
              你的私钥永远不会离开你的钱包。连接后可以查看持仓和交易。
            </p>
          </template>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background: rgba(4, 5, 7, 0.72);
  backdrop-filter: blur(6px);
}

.sheet-panel {
  width: min(100%, 430px);
  background: var(--panel);
  border-radius: 22px 22px 0 0;
  padding: 0 18px calc(22px + env(safe-area-inset-bottom));
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.sheet-handle {
  width: 36px;
  height: 4px;
  border-radius: 99px;
  background: var(--line);
  margin: 12px auto 10px;
}

.sheet-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.sheet-header h3 {
  font-size: 17px;
  font-weight: 800;
}

.sheet-close {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 1px solid var(--line);
  background: transparent;
  font-size: 13px;
  color: var(--muted);
  display: grid;
  place-items: center;
}

.sheet-desc {
  font-size: 12px;
  color: var(--muted);
  line-height: 1.55;
  margin-bottom: 14px;
}

.sheet-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 28px 0;
  color: var(--muted);
  font-size: 13px;
}

.spinner {
  width: 36px;
  height: 36px;
  border: 3px solid var(--line);
  border-top-color: var(--gold2);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.sheet-error {
  padding: 8px 0 4px;
}

.sheet-wallets {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 12px;
}

.wallet-option {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 13px;
  background: var(--panel2);
  border: 1px solid var(--line);
  border-radius: 14px;
  text-align: left;
  width: 100%;
}

.wallet-option:hover {
  border-color: rgba(216, 170, 81, 0.3);
}

.wallet-option-icon {
  font-size: 24px;
  width: 36px;
  text-align: center;
  flex-shrink: 0;
}

.wallet-option-info {
  flex: 1;
}

.wallet-option-info b {
  display: block;
  font-size: 14px;
}

.wallet-option-info small {
  display: block;
  font-size: 10px;
  color: var(--muted);
  margin-top: 2px;
}

.wallet-option-arrow {
  font-size: 20px;
  color: var(--muted);
}

.sheet-footer-text {
  font-size: 10px;
  color: var(--muted);
  text-align: center;
  line-height: 1.5;
}

/* Transition */
.sheet-enter-active,
.sheet-leave-active {
  transition: opacity 0.25s ease;
}
.sheet-enter-active .sheet-panel,
.sheet-leave-active .sheet-panel {
  transition: transform 0.25s cubic-bezier(0.32, 0.72, 0, 1);
}
.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
}
.sheet-enter-from .sheet-panel {
  transform: translateY(100%);
}
.sheet-leave-to .sheet-panel {
  transform: translateY(100%);
}
</style>
