# PANGU2 P2-F07 — DApp Closeout Evidence

- **Date:** 2026-08-02
- **Phase:** PB-S4 (Wave 6 Closeout)
- **Status:** FIX_BEFORE_MERGE (Pending Docker environment for build/test execution)

## 1. ErrorBoundary Global Coverage

**File:** `apps/dapp/src/App.vue`

The `ErrorBoundary` component wraps `<router-view />` at the root level:

```vue
<ErrorBoundary fallback-message="页面渲染失败，请刷新重试。">
  <router-view />
</ErrorBoundary>
```

This catches unhandled Vue render errors across all routed views and displays a recoverable UI with a "Retry" button.

**Component states covered:**
- Default: renders child slot normally
- Error: displays error icon + message + retry button
- Recovery: reset clears error state, re-renders slot

**Component:** `apps/dapp/src/components/common/ErrorBoundary.vue` (previously delivered in P2-F03)

## 2. Accessibility (A11y)

| Component | Accessible Text | Method |
|---|---|---|
| Wallet button | "连接钱包" / address label / "连接中..." | Dynamic `aria-label` on button |
| Network mismatch | "当前网络不支持交易" | `NetworkBanner.vue` visible text |
| Trade submit | "确认买入" / "授权并卖出" / disabled states | Button text + `:disabled` |
| Quote status | "MOCK DATA" / "EXPIRED" / "UNAVAILABLE" / stale indicators | `DataStatusBanner.vue` explicit labels |
| Loading | "Fetching quote..." / "Loading data..." | `LoadingSpinner.vue` with label prop |
| Error | Error message + code + retry action | `ErrorState.vue` with retry button |
| Empty | Icon + title + description | `EmptyState.vue` with action slot |
| Transaction | Phase label (16 states) + tx hash link + block number | `TransactionProgress.vue` overlay |
| Navigation | 首页 / 交易 / 分红 / 我的 | `BottomNav.vue` text labels |

## 3. Mobile Viewport Adaptation

**Design target:** 375px–430px width (mobile-first)

All views use:
- `max-width: 430px` container (`.app`)
- Responsive grid: `repeat(auto-fill, minmax(...))` for KPI cards
- `env(safe-area-inset-*)` for notched devices
- `-webkit-tap-highlight-color: transparent` for touch feedback
- Scrollable tables with `overflow: auto` for wide data

## 4. Build Verification

**Expected commands (run after Docker setup):**

```bash
cd apps/dapp
npm install
npx vue-tsc --noEmit                    # Type check — must exit 0
npx eslint . --ext .vue,.ts             # Lint — must exit 0
npx vite build                          # Production build
```

**Build output expectations:**
- Output directory: `apps/dapp/dist/`
- Gzip bundle size: < 500 KB (target)
- No `.env` files or secrets in bundle
- All `@pangu2/api-types` imports resolve
- No duplicate DTO or business formula code

## 5. E2E Test Coverage

**Test scenarios (Playwright/Cypress):**

| Scenario | Steps | Assertions |
|---|---|---|
| Connect wallet | 1. Click "连接钱包" 2. Approve in MetaMask (Anvil) | Address displayed in topbar, canTransact = true |
| Buy quote fetch | 1. Select "买入" mode 2. Enter "0.1" BNB 3. Wait for quote | Quote card appears, tax_rate = "4.00%", source = "mock" or "contract_preview" |
| Network switch reject | 1. Connect wallet on wrong chain 2. See "Unsupported Network" banner 3. Click switch network 4. Reject in wallet | Banner persists, canTransact remains false |
| Sell flow (happy) | 1. Connect 2. Enter sell amount 3. Get quote 4. Submit + sign 5. Wait for confirmation | TransactionProgress overlay, CONFIRMED state, tx hash link |
| Error recovery | 1. Refuse sign in wallet | "Rejected" banner, "Retry" button restores to READY |
| Empty states | 1. Visit pages without data | EmptyState placeholder with icon+text |

## 6. Deliverables Checklist

| # | Deliverable | Status |
|---|---|---|
| 1 | ErrorBoundary 全局覆盖 | ✓ Applied in `App.vue` |
| 2 | 移动端适配 (375-430px) | ✓ Responsive CSS in all views |
| 3 | 无障碍文本提示 | ✓ All key state changes have visible text labels |
| 4 | vite build 无泄漏 | ⏳ Pending Docker (no Node.js locally) |
| 5 | E2E 测试 | ⏳ Pending Docker (requires Anvil + Mock API running) |
| 6 | lint + typecheck + build 报告 | ⏳ Pending Docker |

## 7. Bundle Analysis (Expected)

| Chunk | Expected Size (gzip) |
|---|---|
| vue runtime | ~35 KB |
| vue-router | ~10 KB |
| pinia | ~6 KB |
| wagmi + viem | ~120 KB |
| @pangu2/api-types | ~2 KB |
| App components (views + common) | ~50 KB |
| CSS | ~8 KB |
| **Total** | **~230 KB** |

Well within the 500 KB target.
