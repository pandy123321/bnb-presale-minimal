<!--
  PANGU2 Admin — AssetsView (Contracts Registry)
  Connects to /contracts API. Displays address, ABI version, deployment block, status.
-->
<script setup lang="ts">
import { useAdminContracts } from "@/features/dashboard/useAdminApi";

const contracts = useAdminContracts();
</script>

<template>
  <div>
    <div class="hero">
      <div>
        <h3>链上资产与合约</h3>
        <p>查看协议合约、受保护资金和链上同步状态。地址、ABI版本、部署区块、状态均从后端读取。</p>
      </div>
      <div class="hero-side">
        <strong>{{ contracts.total }}个合约</strong>
        <small v-if="contracts.loading">Loading...</small>
        <small v-else>ABI Registry v1.0.0</small>
      </div>
    </div>

    <div class="section-head"><h3>合约注册表</h3></div>

    <div v-if="contracts.loading" class="loading-row">Loading contracts...</div>
    <div v-else-if="contracts.error" class="error-row">{{ contracts.error }}</div>
    <div v-else class="card">
      <div class="card-body">
        <div class="table">
          <div class="tr contracts head">
            <span>名称</span><span>地址</span><span>ABI版本</span><span>部署区块</span><span>状态</span>
          </div>
          <div
            v-for="c in contracts.contracts"
            :key="c.name + c.address"
            class="tr contracts"
          >
            <span>
              <b>{{ c.name }}</b>
              <small>{{ c.status === 'ACTIVE' ? 'Active' : c.status }}</small>
            </span>
            <span class="mono copy">{{ c.address }}</span>
            <span>{{ c.abi_version }}</span>
            <span>#{{ c.deployment_block }}</span>
            <span
              class="tag"
              :class="{
                ok: c.status === 'ACTIVE',
                warning: c.status === 'PAUSED' || c.status === 'UNKNOWN',
                danger: (c.status as string) === 'UNAVAILABLE',
              }"
            >
              {{ c.status }}
            </span>
          </div>
          <div v-if="contracts.contracts.length === 0" class="empty-row">
            No contracts registered.
          </div>
        </div>
      </div>
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
.hero p { color: var(--muted); font-size: 12px; }
.hero-side { text-align: right; }
.hero-side strong { display: block; color: var(--gold2); font-size: 20px; }
.hero-side small { color: var(--muted); font-size: 10px; }
.section-head { margin: 24px 0 10px; }
.section-head h3 { font-size: 15px; }

.table { min-width: 900px; overflow: auto; }
.tr {
  display: grid;
  grid-template-columns: repeat(5, minmax(100px, 1fr));
  gap: 12px;
  align-items: center;
  min-height: 48px;
  padding: 8px 14px;
  border-bottom: 1px solid rgba(255,255,255,.05);
  font-size: 11px;
}
.tr.head { min-height: 38px; color: var(--muted); font-size: 10px; background: rgba(255,255,255,.018); }
.tr:last-child { border-bottom: 0; }
.tr.contracts { grid-template-columns: 1.15fr 1.5fr .8fr .8fr .7fr; }
.tr b { display: block; }
.tr small { display: block; color: var(--muted); font-size: 9px; margin-top: 2px; }
.copy { color: var(--gold2); cursor: pointer; }

.tag { padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; }
.tag.ok { color: var(--green); background: rgba(67,207,139,.08); border: 1px solid rgba(67,207,139,.18); }
.tag.warning { color: var(--orange); background: rgba(243,163,75,.08); border: 1px solid rgba(243,163,75,.18); }
.tag.danger { color: var(--red); background: rgba(255,116,125,.08); border: 1px solid rgba(255,116,125,.18); }

.loading-row { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }
.error-row { padding: 16px; border: 1px solid rgba(255,116,125,.2); background: rgba(255,116,125,.04); color: var(--red); font-size: 12px; }
.empty-row { padding: 20px; text-align: center; color: var(--muted); font-size: 12px; }

@media (max-width: 1180px) { .hero { grid-template-columns: 1fr; } }
</style>
