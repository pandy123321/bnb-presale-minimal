# BGP V7.1 DApp 前端重构方案 · 定稿

> **原型来源**：`E:\github\bnb\原型\`（BGP_V7_1_Home / Trade / Portfolio）  
> **目标项目**：`E:\github\bnb\bnb-presale-minimal\apps\dapp\`  
> **日期**：2026-08-05  
> **状态**：方案定稿，待确认后执行

---

## 一、项目性质确认

原型的 3 个页面（Home / Trade / Portfolio）是**用户端 DApp**，面向持有非托管钱包的最终用户。以下规则约束全部开发：

| 规则 | 说明 |
|------|------|
| 用户不注册、不登录 | 仅通过 MetaMask / WalletConnect 连接钱包 |
| 不托管私钥 | 所有签名由用户钱包本地完成 |
| 链上操作需签名 | buy/sell/stake/unstake/claim 均调用钱包签名 |
| 只读数据走 API | 余额、排行榜、交易活动走 Laravel API |
| 数据状态标识 | 所有 mock/预览数据标注 `Preview data` 标签 |

---

## 二、设计系统

### 2.1 原型设计令牌（CSS Tokens）

直接从原型提取，零修改：

```css
--bg:          #070A13
--surface:     #0D1422
--surface-2:   #111A2B
--surface-3:   #151F32
--line:        rgba(182,198,227,.11)
--line-strong: rgba(76,201,240,.28)
--text:        #F7F9FC
--text-2:      #A9B4C8
--text-3:      #718099
--cyan:        #4CC9F0     /* 主强调色 */
--blue:        #2E6BE6
--gold:        #E4B96B     /* 辅助强调色 */
--green:       #39C99B
--red:         #FF7181
--amber:       #E6A85A
--radius:      20px
--radius-sm:   14px
--nav-h:       72px
--page-pad:    16px
--section-gap: 26px
--module-pad:  16px
--module-radius: 20px
--control-radius: 14px
```

### 2.2 布局约束

- `max-width: 430px`，居中显示，移动端优先
- 底部固定导航，3 个 tab：**Home / Trade / Portfolio**
- 顶部 sticky Header（品牌 + 语言 + 钱包按钮）
- 所有子操作使用**半屏 Sheet 浮层**，不跳转新页面
- 全局 Toast 提示

### 2.3 组件体系（纯 CSS，不引入 UI 框架）

| 组件 | 用途 | 原型 CSS 类 |
|------|------|------------|
| `Card` | 标准卡片、软卡片两种层级 | `.card`, `.card.soft` |
| `Button` | 三级按钮 | `.btn.primary`, `.btn.secondary`, `.btn.text` |
| `ButtonGroup` | 分段控制器（Buy/Sell 切换） | `.segmented` |
| `Tag` | 状态标签 | `.tag`, `.tag.demo`, `.tag.locked`, `.tag.open` |
| `SectionHead` | 区域标题 + 渐变装饰线 | `.section-head` |
| `Sheet` | 半屏浮层容器 | `.overlay` > `.sheet` |
| `Toast` | 全局操作反馈 | `.toast` |
| `MetricBlock` | 标签 + 数值块 | `.metric-label` + `.metric-value` |
| `DetailList/DetailRow` | 键值对列表 | `.detail-list` / `.detail-row` |
| `WalletConnectSheet` | 钱包选择浮层 | `.choice` 列表 |
| `DonutChart` | 锁仓/分发占比环图 | CSS conic-gradient |
| `ProgressBar` | 交易操作步骤指示 | `.progress` |

---

## 三、路由设计

### 3.1 路由表（3 条）

| 路径 | 名称 | 页面 | 说明 |
|------|------|------|------|
| `/` | `home` | `HomePage.vue` | Hero + 钱包位 + 协议 + Why + 排行榜 |
| `/trade` | `trade` | `TradePage.vue` | 市场 + Buy/Sell + 活动 |
| `/portfolio` | `portfolio` | `PortfolioPage.vue` | 资产 + 锁仓 + 团队 + 推荐 |

**旧路由全部删除**（HomeView / TradeView / DividendView / StakingView / SupportView / MeView）。

### 3.2 底部导航（3 个 tab）

```
┌──────────┬──────────┬──────────────┐
│  Home    │  Trade   │  Portfolio   │
│  (首页)  │  (交易)  │  (资产组合)   │
└──────────┴──────────┴──────────────┘
```

---

## 四、页面详细设计

### 4.1 Home 页面

| 区块 | 数据来源 | 备注 |
|------|----------|------|
| Hero Banner | 静态文案 + 价格/持币人数/流动性（API） | 三条价值卡片硬编码 |
| 钱包位卡片 | `Wallets/{address}/summary` API | 余额 + BNB 估值 + 变化率 + 锁仓比 |
| 资产操作入口（Rewards / Locked / Rank） | API + 链上 | 点击打开对应 Sheet |
| 协议参数 | API config | 税率 4%、回购 0.01 BNB、间隔 60s |
| Why BGP | 静态文案 | 纯展示 |
| 排行榜 Top 5 | API（rankings 端点） | 若无 API 则标注 Preview data |

### 4.2 Trade 页面

| 区块 | 数据来源 | 备注 |
|------|----------|------|
| 价格图表区 | **特殊规则** | 见 §4.2.1 |
| 市场指标（24h High/Low/Volume） | API / Oracle | — |
| Buy/Sell 分段控制器 | 复用 `useQuote` composable | — |
| 交易输入框 + 快捷比例 + MAX | 复用 | UI 按原型重建 |
| 报价详情展开 | 复用 `quoteDetails` | 税率、净收、最低收、报价区块 |
| 交易活动列表 | API | 最近的 buy/sell 事件 |
| 操作进度条 | 复用 `TransactionProgress` | — |

#### 4.2.1 价格图表特殊规则

```
┌──────────────────────────────────────────────────────┐
│  BGP / BNB                                      ···  │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │                                              │   │
│  │     Trading not yet activated                │   │
│  │     交易尚未开启                              │   │
│  │                                              │   │
│  │     The administrator will enable trading     │   │
│  │     after oracle finalization.                │   │
│  │     管理员将在 Oracle 就绪后手动开启交易。     │   │
│  │                                              │   │
│  │     No countdown. Check back later.           │   │
│  │     暂无倒计时，请稍后查看。                   │   │
│  │                                              │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  24h High      24h Low      24h Volume               │
│  --            --           --                       │
└──────────────────────────────────────────────────────┘
```

| 规则 | 说明 |
|------|------|
| 不自动开启 | 不依赖前端倒计时或自动检测 |
| 不显示倒计时 | 不暗示用户"X 分钟后开启" |
| 后台手动确认 | Admin 后台设置 `trading_enabled` 标志 |
| 开启前展示 | 图表区显示 "Trading not yet activated" 中性提示 |
| 开启后切换 | 轮询 API `trading_enabled` 字段，`true` 时渲染真实图表 + 启用交易输入 |
| 市场指标 | 开启前显示 `--`，开启后显示真实数据 |

#### 4.2.2 交易开启后的 Buy/Sell 流程

```
用户输入金额
  → POST /quotes/buy (或 sell) 获取报价
  → 展示报价详情（30s 有效期，过期自动刷新）
  → 用户确认 → 钱包签名 → 链上确认
  → ProgressBar 进度展示
  → Toast 完成提示
```

### 4.3 Portfolio 页面

| 区块 | 数据来源 | 备注 |
|------|----------|------|
| 资产总览卡片 | `WalletSummary` API | 余额 + BNB 估值 + 变化率 |
| 3 个关键指标 | 同上 | 锁仓量、可用量、锁仓比 |
| 分发 Donut 环图 | 链上 positions + API | 锁仓 / 流通 / 团队 |
| 锁仓操作 Sheet | 复用 `useStaking` | Lock / Unstake / EarlyUnstake / ClaimRewards |
| 我的团队卡片 | API（若无则 Preview） | 团队人数 + 总锁仓 + 增长曲线 |
| 网络概览条 | API | 当前在线、总节点、日增长 |
| 推荐链接 + 分享 | 纯前端 | 生成 ref link + 复制 |
| 邀请记录列表 | API（若无则 Preview） | — |
| 回购/锁仓批次 | 复用 `useSupport` | — |

### 4.4 共通交互规则

| 交互模式 | 实现 |
|------|------|
| 刷新 | 页面进入时拉取 + 下拉刷新（移动端） |
| 数据状态 | 所有 API 响应带 `data_status`（LIVE / STALE / MOCK_DATA），前端展示对应标签 |
| 错误处理 | API 失败展示 ErrorState 组件 + 重试按钮 |
| 空数据 | 展示 EmptyState + 引导文案 |
| 加载中 | Skeleton 或 LoadingSpinner |
| 钱包未连接 | 需要钱包的操作弹出 WalletConnectSheet |

---

## 五、组件树

```
App.vue
├── HeaderBar (brand + language + wallet button)
├── <router-view />
│   ├── HomePage.vue
│   │   ├── SectionHead (Protocol / HolderRanking)
│   │   ├── Card (wallet-position / protocol / ranking)
│   │   ├── MetricBlock (Rewards / Locked / Rank entries)
│   │   └── Tag (Preview data)
│   ├── TradePage.vue
│   │   ├── MarketCard (price chart / 24h metrics / trading-disabled overlay)
│   │   ├── OrderPanel
│   │   │   ├── ButtonGroup (Buy / Sell)
│   │   │   ├── TradeInput + QuickButtons + MAX
│   │   │   ├── QuoteDetails (DetailList)
│   │   │   └── Button (Confirm)
│   │   ├── ActivityList (DetailList of recent trades)
│   │   └── ProgressBar
│   └── PortfolioPage.vue
│       ├── Card (wallet-position + balance overview)
│       ├── DonutChart (distribution)
│       ├── Sheet (lock / unstake / claim)
│       ├── SectionHead (MyTeam / Referral)
│       ├── Card (team stats)
│       ├── Card (referral link + invite list)
│       └── Card (buyback / locker batches)
├── BottomNav (3 tabs: Home / Trade / Portfolio)
├── WalletConnectSheet (overlay + choice list)
├── Sheet (generic overlay for lock / unstake / claim / details)
└── Toast
```

---

## 六、状态管理 & 数据流

### 6.1 数据源分类

| 类别 | 来源 | 实例 |
|------|------|------|
| **链上只读** | viem `readContract` | 代币余额、锁仓仓位、Oracle 状态 |
| **链上写入** | wagmi `writeContract` | buy、sell、stake、unstake、claim |
| **API 读取** | `Pangu2ApiClient` → Laravel | 排行榜、交易活动、钱包汇总、市场指标 |
| **API 写入** | 无 | DApp 不通过 API 写入 |
| **静态内容** | 硬编码 + i18n | Hero 文案、Why BGP、价值卡片 |

### 6.2 数据流向

```
用户操作 → Composable (useXxx) → API Client / wagmi / viem
                                         ↓
            Pinia Store ← (可选，跨组件共享状态)
                ↓
            View (reactive rendering)
```

### 6.3 Pinia Store 保留（精简）

| Store | 用途 |
|-------|------|
| `useWalletStore` | 钱包连接状态 + 网络状态，**保留** |
| `useDataStore` | 全局 config + system-status，**保留** |
| `useDataStatusStore` | 数据新鲜度追踪，**保留** |

### 6.4 Composable（从 features/ 重构）

| Composable | 作用 | 调用方式 |
|------------|------|----------|
| `useQuote` | Buy/Sell 报价获取 & 有效期管理 | TradePage 独占 |
| `useTransaction` | 链上交易执行 & 状态追踪 | TradePage 独占 |
| `useStaking` | stake/unstake/earlyUnstake/claimRewards | PortfolioPage 独占 |
| `usePortfolio` | 钱包汇总 + 锁仓位 + 分发数据 | PortfolioPage 独占 |
| `useMarket` | 价格 + 图表数据 + 24h 指标 + `trading_enabled` 检测 | TradePage 独占 |
| `useRanking` | 排行榜数据 | HomePage 独占 |
| `useReferral` | 推荐链接 + 邀请记录 | PortfolioPage 独占 |

---

## 七、分阶段执行计划

### Phase 1：地基（只建不拆）

> 不影响现有任何页面，新旧路由共存

| 任务 | 产出 |
|------|------|
| 从原型提取 CSS tokens → `styles/tokens.css` | 全局设计变量 |
| 创建共享基础组件 | `Card.vue`, `Button.vue`, `Tag.vue`, `SectionHead.vue`, `Sheet.vue`, `BottomNav.vue`, `Toast.vue`, `MetricBlock.vue`, `DetailList.vue` |
| 创建 3 个空白页面 + 新路由 | `HomePage / TradePage / PortfolioPage` |
| 新旧路由共存 | `/` → 新 HomePage, `/old-home` → 旧 HomeView（开发期参考） |

### Phase 2：Home 页面

| 优先级 | 任务 | 数据源 |
|--------|------|--------|
| P0 | Hero Banner + 三条价值卡片 | 静态 |
| P0 | 协议参数卡片 | API config |
| P1 | 钱包位卡片（余额 + 估值 + 变化） | API WalletSummary |
| P1 | 资产操作入口（Rewards/Locked/Rank） | API + 链上 |
| P2 | Why BGP | 静态 |
| P2 | 排行榜 Top 5 | API rankings |

### Phase 3：Trade 页面（核心页面）

| 优先级 | 任务 | 说明 |
|--------|------|------|
| P0 | `trading_enabled` 状态检测 + 未开启提示 | 应用 §4.2.1 特殊规则 |
| P0 | Buy/Sell 交易区 | 复用 useQuote + useTransaction |
| P0 | 报价详情 + 确认流程 | 复用现有逻辑 |
| P1 | 价格图表（开启后才渲染） | Canvas 或 lightweight-charts |
| P1 | 24h High/Low/Volume 指标 | API / Oracle |
| P2 | 交易活动列表 | API |

### Phase 4：Portfolio 页面

| 优先级 | 任务 | 说明 |
|--------|------|------|
| P0 | 资产总览卡片 | 复用 WalletSummary |
| P0 | 锁仓操作 Sheet | 复用 useStaking 链调用 |
| P1 | 分发 Donut 环图 | CSS conic-gradient |
| P1 | 回购/锁仓批次 | 复用 useSupport |
| P2 | 我的团队卡片 | API / Preview |
| P2 | 推荐链接 + 邀请记录 | 纯前端 / API |

### Phase 5：清理

| 任务 |
|------|
| 删除 6 个旧页面（HomeView / TradeView / DividendView / StakingView / SupportView / MeView） |
| 删除旧 BottomNav / ConnectSheet |
| 清理 features/ 中不再使用的 composable |
| 删除 packages/mock-api（改为全量依赖真实 API） |

---

## 八、图表库选型

采用 **lightweight-charts**（TradingView 出品，~40KB gzipped），理由：

- 与 Vue 3 无冲突，通过 `ref` 挂载 canvas 节点即可
- 内置暗色主题支持，与原型设计系统无缝匹配
- 支持实时数据更新，API 就绪后直接推送价格点
- 用户侧体验：轻量流畅，移动端触摸交互友好

| 集成方式 | 说明 |
|----------|------|
| 引入 | `npm install lightweight-charts`，按需 import |
| 挂载 | `onMounted` 中 `createChart(containerRef)` |
| 更新 | `watch` 价格数据 → `series.update(point)` |
| 销毁 | `onUnmounted` 中 `chart.remove()` |
| 未开启时 | 不创建图表实例，仅渲染占位提示 |

---

## 九、风险与依赖

| 风险 | 影响范围 | 缓解措施 |
|------|----------|----------|
| 合约未 Finalize，Oracle 不可用 | Trade 页面全部只读（价格/报价/交易均不可用） | §4.2.1 已设计未开启状态覆盖 |
| 排行榜 / 团队 / 推荐后端尚无 API | Home + Portfolio 部分区域暂不开发 | 等 API 就绪后再实现，不预先 mock |
| bootstrap 未完成，LP 无代币余额 | 锁仓操作无法端到端 | 先用 Anvil 本地链验证 UI |
| `SCOPE_LOCK.md` 中"用户端"列为非范围 | 文档冲突 | 已明确：原型为目标，SCOPE_LOCK 为旧文档，以原型为准 |

---

## 十、Admin 后台

本轮 **不改造** `apps/admin/`。唯一需要 Admin 配合的：

| 后续任务 | 说明 |
|------|------|
| Trading 开关 | Admin Dashboard 增加"开启/关闭交易"按钮，设置 `trading_enabled` 字段 |
| 前端轮询 | TradePage 每 30s 轮询 `trading_enabled` 状态 |

此项不计入本轮 DApp 重构范围。

---

## 十一、旧页面删除时机

Phase 2-4 期间新旧路由共存，旧页面保留作为开发参考。**Phase 5 统一删除**以下全部：

| 删除的文件 | 原因 |
|------|------|
| `views/HomeView.vue` | 取代为 HomePage |
| `views/TradeView.vue` | 取代为 TradePage |
| `views/DividendView.vue` | 合并到 PortfolioPage |
| `views/StakingView.vue` | 合并到 PortfolioPage |
| `views/SupportView.vue` | 合并到 PortfolioPage |
| `views/MeView.vue` | 合并到 PortfolioPage |
| `components/BottomNav.vue` (旧版) | 取代为新 3-tab 版 |
| `components/ConnectSheet.vue` (旧版) | 取代为 WalletConnectSheet |
| `components/DataStatusBanner.vue` (根目录版) | 重复组件，已迁移到 common/ |
| `components/ErrorState.vue` (根目录版) | 同上 |
| `components/EmptyState.vue` (根目录版) | 同上 |
| `components/LoadingSpinner.vue` (根目录版) | 同上 |
| 不再使用的 features/composables | 代码审查后按需删除 |

---

## 十二、待确认事项（已全部确认）

| # | 问题 | 决策 |
|---|------|------|
| 1 | 排行榜 / 团队 / 推荐三个模块：先 mock 还是等 API？ | **等 API 就绪后再实现**，不预先 mock |
| 2 | 价格图表库选型 | **lightweight-charts**，~40KB，原生暗色主题，移动端友好 |
| 3 | Admin 后台是否跟随改造？ | **本轮不改造**，仅 TradePage 轮询 `trading_enabled` |
| 4 | 旧页面删除时机 | **Phase 5 统一删除**，开发期新旧共存 |

---

> **定稿状态**：方案已确认，所有待确认事项已决策。等待审核通过后从 Phase 1 开始执行。
