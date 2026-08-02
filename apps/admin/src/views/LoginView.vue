<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAdminAuthStore } from "@/stores/useAdminAuth";

const router = useRouter();
const auth = useAdminAuthStore();

const email = ref("admin@pangu2.io");
const password = ref("");
const submitting = ref(false);

async function handleLogin() {
  submitting.value = true;
  auth.error = null;
  const ok = await auth.login(email.value, password.value);
  submitting.value = false;
  if (ok) {
    router.push("/");
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-brand">
        <div class="logo">P2</div>
        <h1>PANGU2 Console</h1>
        <p>链上运营控制台</p>
      </div>

      <form @submit.prevent="handleLogin">
        <div class="field">
          <label>Email</label>
          <input v-model="email" type="email" placeholder="admin@pangu2.io" autocomplete="email">
        </div>
        <div class="field">
          <label>Password</label>
          <input v-model="password" type="password" placeholder="Enter password" autocomplete="current-password">
        </div>

        <div v-if="auth.error" class="login-error">{{ auth.error }}</div>

        <button type="submit" class="login-btn" :disabled="submitting || !email || !password">
          {{ submitting ? '登录中...' : '登录' }}
        </button>
      </form>

      <p class="login-note">后台不托管用户私钥，不修改用户资产或分红结果。</p>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: radial-gradient(circle at 84% -10%, rgba(214,173,95,.08), transparent 28%),
              radial-gradient(circle at 20% 120%, rgba(118,169,255,.05), transparent 26%),
              var(--bg);
}

.login-card {
  width: 100%;
  max-width: 400px;
  padding: 36px;
  border: 1px solid var(--line);
  background: var(--panel);
}

.login-brand {
  text-align: center;
  margin-bottom: 28px;
}

.logo {
  width: 52px;
  height: 52px;
  margin: 0 auto 14px;
  display: grid;
  place-items: center;
  border: 1px solid rgba(214,173,95,.5);
  background: linear-gradient(145deg, rgba(214,173,95,.18), rgba(214,173,95,.035));
  font-weight: 900;
  color: var(--gold2);
  font-size: 22px;
  letter-spacing: -1px;
}

.login-brand h1 {
  font-size: 20px;
  margin: 0;
  font-weight: 750;
}

.login-brand p {
  margin: 5px 0 0;
  color: var(--muted);
  font-size: 12px;
}

.field {
  margin-bottom: 14px;
}

.field label {
  display: block;
  color: var(--muted);
  font-size: 11px;
  margin-bottom: 5px;
}

.field input {
  width: 100%;
  height: 42px;
  padding: 0 12px;
  border: 1px solid var(--line);
  background: var(--panel2);
  color: var(--text);
  font-size: 13px;
  outline: 0;
}

.field input:focus {
  border-color: rgba(214,173,95,.45);
}

.login-error {
  padding: 9px 12px;
  border: 1px solid rgba(255,114,125,.22);
  background: rgba(255,114,125,.05);
  color: var(--red);
  font-size: 11px;
  margin-bottom: 14px;
}

.login-btn {
  width: 100%;
  height: 44px;
  border: 0;
  background: linear-gradient(145deg, var(--gold2), var(--gold));
  color: #15120c;
  font-size: 13px;
  font-weight: 750;
  cursor: pointer;
}

.login-btn:disabled {
  opacity: .45;
  cursor: not-allowed;
}

.login-note {
  margin-top: 18px;
  color: var(--muted2);
  font-size: 10px;
  text-align: center;
  line-height: 1.6;
}
</style>
