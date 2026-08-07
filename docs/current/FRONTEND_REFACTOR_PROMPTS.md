# DApp V7.1 重构 · 执行提示词

> **使用方式**：按 Phase 顺序执行。每个 Phase 的提示词独立，复制后直接发给 AI 编码 Agent。

---

## Phase 1 提示词：基础设施（CSS Tokens + 基础组件 + 空白路由）

```
你是前端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 任务
基于 BGP V7.1 原型建立 DApp 前端重构的基础设施。不修改现有业务代码。

## 关键约束
- 所有样式从原型文件提取，零修改
- 原型文件位置：E:\github\bnb\原型\BGP_V7_1_*.html
- 目标项目：apps/dapp/
- 只建不拆：新旧路由共存，旧页面保留

## 具体步骤

### Step 1：创建 packages/ui/tokens.css
从原型 `<style>` 标签中提取全部 CSS 变量并放入 tokens.css：
- 颜色：--bg, --surface, --surface-2, --surface-3, --line, --line-strong, --text, --text-2, --text-3, --cyan, --blue, --gold, --green, --red, --amber
- 尺寸：--radius, --radius-sm, --nav-h, --page-pad, --section-gap, --module-pad, --module-radius, --control-radius

### Step 2：创建 packages/ui/global.css
从原型提取全局基础样式：
- *, html, body 重置
- .app 容器（max-width: 430px, 居中, 暗色背景）
- .header（sticky, blur 背景）
- main 布局
- 字体栈：Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang TC", "Noto Sans JP", "Noto Sans KR", sans-serif

### Step 3：创建 packages/ui/components/ 目录和以下 7 个基础 Vue 组件
每个组件从原型对应的 CSS class 提取样式，放入 <style scoped>：

1. Card.vue — 支持 variant="default"|"soft"
2. Button.vue — 支持 variant="primary"|"secondary"|"text" + disabled 状态
3. Tag.vue — 支持 variant="demo"|"locked"|"open"
4. SectionHead.vue — 渐变装饰线 + 标题 + 可选的右侧操作按钮/标签
5. Sheet.vue — 半屏浮层（overlay + sheet 容器 + handle + head + body + close 按钮）
6. BottomNav.vue — 3 个 tab（Home/Trade/Portfolio），active 状态有渐变下划线
7. Toast.vue — 全局提示，支持 show/hide 动画

### Step 4：创建 3 个空白 Vue 页面
在 apps/dapp/src/views/ 下创建（只写骨架，不写业务内容）：
- HomePage.vue — 页面标题 "Home"，引用 SectionHead + Card
- TradePage.vue — 页面标题 "Trade"
- PortfolioPage.vue — 页面标题 "Portfolio"

### Step 5：更新路由 apps/dapp/src/router/index.ts
- 新增 3 条路由映射到新页面
- 旧 6 条路由保留
- 首页 / 指向 HomePage

### Step 6：验证
- pnpm -r typecheck 无错误
- 浏览器打开能看到 3 个新页面（内容为空但布局正确）
- 旧 6 个页面仍然可访问

不要修改 apps/admin/。
不要修改旧页面的任何代码。
```

---

## Phase 2 提示词：Home 页面

```
你是前端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 任务
按照 BGP V7.1 原型实现 Home 页面。原型文件：E:\github\bnb\原型\BGP_V7_1_Home.html

## 页面结构（严格按原型）

### 1. Hero Banner（.hero）
- 顶部：BGP / BNB 交易对标签 + 网络标识圆点
- 标题："Precision meets growth."（英文，支持 i18n）
- 副标题：简短描述
- 3 个指标：Price（含变化率百分比）、Holders、Liquidity
- 2 个 CTA 按钮："Trade BGP"（primary）→ /trade、"View portfolio"（secondary）→ /portfolio
- 3 条价值卡片："Transparent by design"、"Community aligned"、"Flexible commitment"

### 2. 钱包位卡片（.card.wallet-card）
- 标题："Wallet position" + 地址缩写 + Demo 标签
- 余额（BGP 大号字体） + BNB 估值 + 变化率
- SVG 迷你趋势图（用原型中的 sparkline SVG）
- 3 个操作入口：Rewards / Locked / Rank，每个显示数值

### 3. 协议参数卡片（.section > .card）
- 标题 "Protocol" + "Details" 按钮
- 3 行：Community rewards 4% / Buyback size 0.01 BNB / Minimum interval 60s
- 数据来自 API GET /v1/projects/pangu2/config

### 4. Why BGP（.why-banner）
- 静态文案（原型中提取，支持 i18n）
- 3 个 pill 标签：Precision / Participation / Commitment

### 5. 排行榜（#rankingSection）
- 标题 "Holder ranking" + Preview data 标签
- Top 5 行，每行：排名号、地址缩写、标签、BGP 数量、锁仓量标签
- 先写死原型中的 mock 数据，后续等排行榜 API 了就接上

## 数据接入
- 钱包余额 → 复用现有的 useWallet store + API WalletSummary
- 协议参数 → API config（已有 composable）
- 排行榜 → 暂无 API，写死原型数据，标注 Preview data

## 约束
- 不修改 apps/admin/
- 不删除旧页面
- TypeScript strict 通过
```

---

## Phase 3 提示词：Trade 页面

```
你是前端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 任务
按照 BGP V7.1 原型实现 Trade 页面。原型文件：E:\github\bnb\原型\BGP_V7_1_Trade.html

## 最关键的规则：价格图表

**默认状态：交易未开启**
- 不创建图表实例
- 不显示倒计时
- 不显示任何"即将开启"的暗示
- 图表区域展示占位提示："Trading not yet activated / 交易尚未开启"
- 副文案："The administrator will enable trading after oracle finalization. / 管理员将在 Oracle 就绪后手动开启交易。"
- 第三行："No countdown. Check back later. / 暂无倒计时，请稍后查看。"

**检测到 trading_enabled=true 时**
- 每 30s 轮询 API 字段 `trading_enabled`
- 一旦为 true：创建 lightweight-charts 实例
- 渲染价格图表 + 启用交易输入

## 页面结构（严格按原型）

### 1. 市场卡片（.market）
- 交易对标签 BGP / BNB + 价格（大号） + 24h 变化率
- 图表区：未开启时显示上述占位提示；开启后渲染 lightweight-charts 蜡烛图/线图
- 3 个市场指标：24h High / 24h Low / 24h Volume（未开启时显示 --）

### 2. 交易面板（.order-panel）
- Buy/Sell 分段控制器（ButtonGroup）
- 交易输入框：大号字体 + 快捷比例按钮（25%/50%/75%/MAX）+ 代币标签
- 交换箭头（Swap 图标，Buy→Sell 切换方向）
- 报价详情展开（DetailList）：税率、净收、最低收、报价区块
- 确认按钮（primary）
- 注意：未开启交易时输入框 disabled，按钮不可点击

### 3. 交易进度条（.progress）
- 步骤指示：确认交易 → 钱包签名 → 链上确认 → 完成

### 4. 交易活动列表（.activity）
- 最近的买入/卖出记录
- 每行：类型标签（buy 绿/sell 红）、数量、时间、状态

## 技术实现
- 复用现有的 useQuote composable（quote 获取 + 30s 过期）
- 复用现有的 useTransaction composable（链上交易 + 状态追踪）
- 新建 useMarket composable：封装 lightweight-charts 实例 + trading_enabled 轮询 + 24h 指标
- lightweight-charts 安装：pnpm add lightweight-charts --filter @pangu2/dapp
- 图表在 onMounted 创建，onUnmounted 销毁

## 约束
- 不修改 apps/admin/
- TypeScript strict 通过
- pnpm -r typecheck 通过
```

---

## Phase 4 提示词：Portfolio 页面

```
你是前端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 任务
按照 BGP V7.1 原型实现 Portfolio 页面。原型文件：E:\github\bnb\原型\BGP_V7_1_Portfolio.html

## 页面结构（严格按原型）

### 1. 资产总览卡片（.portfolio-card）
- 标题 "Wallet position" + 地址缩写 + Demo 标签
- 大号余额（BGP）+ BNB 估值 + 24h 变化率（绿色百分比）
- 3 个指标：锁仓量、可用量、锁仓比
- 数据来源：API /wallets/{address}/summary

### 2. 分发 Donut 环图
- CSS conic-gradient 实现（不依赖图表库）
- 3 段：锁仓（cyan）、流通（gold）、团队（purple）
- 图例列表：锁仓/流通/团队的数量和百分比

### 3. 锁仓操作
- 复用 useStaking composable
- Lock Sheet：金额输入 + 锁仓天数预设（30/90/180/365）+ 解锁日期自动计算 + 确认按钮
- Unstake / EarlyUnstake / ClaimRewards 入口
- 已锁仓位列表：金额、到期日、状态标签

### 4. 我的团队卡片（.team-grid）
- "My team" 标题 + Preview data 标签
- 3 个统计块：团队人数、总锁仓量、团队等级
- SVG 装饰视觉元素
- 网络概览条：当前在线、总节点、日增长

### 5. 推荐链接
- Share BGP 卡片
- 推荐码 + 复制按钮
- QR 码占位（.qr-panel）

### 6. 邀请记录列表（.referral-list）
- 每行：地址缩写、时间、级别、BGP 奖励
- Preview data 标签
- 暂无 API 时写死原型数据

### 7. 回购/锁仓批次
- 复用 useSupport composable
- 回购历史时间线
- 锁仓批次列表：ID、代币数量、到期日、状态

## 数据接入
- 资产数据 → WalletSummary API（已有）
- 锁仓操作 → useStaking composable（已有，链调用保留）
- 回购/锁仓 → useSupport composable（已有）
- 团队/推荐 → 暂无 API，写死原型数据，标注 Preview data

## 约束
- 不修改 apps/admin/
- TypeScript strict 通过
- 所有 Sheet 操作使用 Phase 1 的 Sheet 组件
```

---

## Phase 5 提示词：清理旧代码

```
你是前端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 任务
删除 DApp 重构后不再需要的旧代码。只做删除和导入修复，不新增功能。

## 删除清单

### 页面（apps/dapp/src/views/）
- HomeView.vue
- TradeView.vue
- DividendView.vue
- StakingView.vue
- SupportView.vue
- MeView.vue

### 组件（apps/dapp/src/components/）
- BottomNav.vue（根目录版，保留 common/ 版本）
- ConnectSheet.vue（根目录版）
- DataStatusBanner.vue（根目录版，common/ 已有替代）
- ErrorState.vue（根目录版）
- EmptyState.vue（根目录版）
- LoadingSpinner.vue（根目录版）

### 路由清理
- 删除 router/index.ts 中 6 条旧路由
- 确认只有 3 条新路由：home, trade, portfolio

### 未使用的 composable 清理
检查 features/ 目录下的 composable，如果不再被任何页面引用则删除。

### 验证
- pnpm -r typecheck 通过，无 "Cannot find module" 错误
- Vite build 成功
- 浏览器打开只有 3 个 tab，功能正常
- 搜索项目中无残留的旧文件引用

## 约束
- 不删除 features/ 中仍然被 PortfolioPage/TradePage 引用的 composable
- 不删除 stores/ 中的任何文件
- 不删除 api/ 中的文件
- 不修改 apps/admin/
```

---

## 执行顺序总结

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
  ↓        ↓        ↓        ↓        ↓
 地基     Home     Trade    Portf    清理
1-2天    2-3天    3-4天    3-4天    1-2天
         ←───── 新旧路由共存 ─────→
```

每个 Phase 完成后验证 `pnpm -r typecheck` 通过再进下一 Phase。
