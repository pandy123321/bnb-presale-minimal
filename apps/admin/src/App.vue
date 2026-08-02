<script setup lang="ts">
import Sidebar from "@/layouts/Sidebar.vue";
import Topbar from "@/layouts/Topbar.vue";
</script>

<template>
  <div class="app">
    <Sidebar />
    <div class="shell">
      <Topbar />
      <main>
        <div class="mock-banner" v-if="true">
          <b>MOCK_DATA</b>
          <span>当前为模拟数据环境，不代表真实链上状态。</span>
        </div>
        <router-view />
      </main>
    </div>
  </div>
</template>

<style scoped>
.app {
  min-height: 100vh;
  display: grid;
  grid-template-columns: 248px minmax(0, 1fr);
  background: radial-gradient(circle at 84% -10%, rgba(214,173,95,.08), transparent 28%),
              radial-gradient(circle at 20% 120%, rgba(118,169,255,.05), transparent 26%),
              var(--bg);
}

.shell { min-width: 0; }

main {
  padding: 22px 24px 40px;
  max-width: 1600px;
  margin: 0 auto;
}

.mock-banner {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 10px 12px;
  border: 1px solid rgba(241,170,85,.25);
  background: rgba(241,170,85,.055);
  margin-bottom: 16px;
  color: #e6c28b;
  font-size: 11px;
}

@media (max-width: 820px) {
  .app { display: block; }
  main { padding: 14px 14px 88px; }
}
</style>
