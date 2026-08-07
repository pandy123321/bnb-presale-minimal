# PANGU2 项目功能文档

## 一、V2 智能合约（contracts-v2/src/）

### 合约清单（11 个）

| 合约 | 职责 |
|------|------|
| **Pangu2Token** | ERC-20 代币 + 税收结算 + Transfer Hook + 白名单 |
| **Pangu2TradeRouter** | 买/卖入口 + 预览报价 + TWAP 价格 |
| **CostBasisManager** | WBNB 成本追踪 + 利润判定 (KNOWN/UNKNOWN/NONE) |
| **FeeVault** | 税费归集 + DIVIDEND/SUPPORT 双 Bucket |
| **SupportPool** | 0.01 BNB 固定回购, 60s 冷却 |
| **BuybackLocker** | 回购代币锁仓, FIXED_DURATION 365 天 |
| **DividendDistributor** | 前 100 名分红 + Merkle Proof + Epoch |
| **Pangu2Staking** | 用户锁仓, 30 天奖励周期, 10% 罚金, O(1) 奖励计算 |
| **PancakeV2Adapter** | PancakeSwap V2 swap/quote |
| **PancakeV2TwapOracle** | 累积价格 TWAP + 低流动性保护 |
| **Pangu2Staking** | Governance 直接持有 admin |

### 税收体系

| 场景 | 税率 | 流向 |
|------|:---:|------|
| 普通买入 | 4% | DividendDistributor |
| 普通卖出（未盈利/UNKNOWN） | 4% | SupportPool |
| 盈利卖出 | 10% | 9% SupportPool + 1% Burn |
| **Launch 保护期（前 15 分钟）** | | |
| ─ Launch 买入 | 30% | DividendDistributor |
| ─ Launch 卖出 | 30% | 29% SupportPool + 1% Burn + 70% Swap |
| **白名单** | | |
| ─ 白名单买入 | 0% | — |
| ─ 白名单卖出 | 0% | — |

### 利润判定

```
KNOWN 且 TWAP ≤ proportionalCost → 4% (普通卖出)
其他 → 10% (盈利卖出)
```

### 其他参数

| 参数 | 值 |
|------|-----|
| 总供应量 | 1,000,000,000 PANGU2 |
| 回购金额 | 0.01 BNB, 60s 冷却 |
| 锁仓 | 365 天 FIXED_DURATION |
| 分红 | Tier 1(1-10):35%, Tier 2(11-30):25%, Tier 3(31-60):25%, Tier 4(61-100):15% |
| 最小质押 | 1 PANGU2, 最长 730 天 |
| 提前解锁罚金 | 10% |
| 奖励速率上限 | ~10 PANGU2/天 |
| Oracle TWAP 窗口 | 30 分钟 |
| Spot/TWAP 最大偏差 | 300 bps (3%) |

### 部署流程

```
Stage 1: DeployPangu2     → 部署 11 合约 + 权限移交 + deployer renounce
Stage 2: BootstrapPangu2  → 初始流动性注入 + Oracle anchor 设定
Stage 3: 等 30 分钟 TWAP 窗口
Stage 4: FinalizePangu2   → 第二次 update() + 双向报价验证
Stage 5: OpenTradingPangu2 → Governance 一次性开启交易 (不可逆)
```

### 治理操作（Governance 权限）

| 操作 | 合约方法 |
|------|----------|
| 开启交易（一次性不可逆） | `setTradingOpenAt()` |
| 设置 Fee 白名单 | `setFeeWhitelist()` / `setFeeWhitelistBatch()` |
| 暂停/恢复 | `pause()` / `unpause()` |
| 触发回购 | `SupportPool.buyback()` |
| Oracle 更新 | `PancakeV2TwapOracle.update()` |
| 释放锁仓 | `BuybackLocker.release(batchId)` |
| 充入分红资金 | `FeeVault.fundDividendDistributor()` |
| Staking 充值/设率 | `fundRewards()` / `setRewardRate()` |

---

## 二、后端 API（backend/）

### Auth & 响应格式

- **认证**: Laravel Session (web guard) + CSRF Token
- **Admin 登录**: `POST /admin-api/v1/projects/pangu2/auth/login` {email, password}
- **CSRF**: `GET /admin-api/.../csrf-token` → X-CSRF-TOKEN header
- **响应格式**: `ApiEnvelope { success, data, meta, error }`

### RBAC 角色

| 角色 | 权限 |
|------|------|
| SUPER_ADMIN | 全部权限 |
| OPERATOR | Dashboard + Contracts + Jobs(读/重试) + Staking(读/管理) + Governance(读) |
| AUDITOR | Dashboard + Contracts + Jobs(读) + Audit + Staking(读) |
| VIEWER | Dashboard + Contracts + Jobs(读) + Staking(读) |

### 公开 API

#### 系统
- `GET /api/v1/projects/pangu2/config` — 链配置
- `GET /api/v1/projects/pangu2/system-status` — 链状态

#### 报价
- `POST /api/v1/projects/pangu2/quotes/buy` {amount_bnb_wei} ⚠️ Mock/UNAVAILABLE
- `POST /api/v1/projects/pangu2/quotes/sell` {amount_token_raw, wallet_address} ⚠️ Mock/UNAVAILABLE

#### 分红
- `GET /api/v1/projects/pangu2/dividend/epochs/current` — 当前 Epoch
- `GET /api/v1/projects/pangu2/dividend/epochs/{id}` — 指定 Epoch
- `GET /api/v1/projects/pangu2/dividend/epochs/{id}/proof/{address}` — 领取证明

#### 回购
- `GET /api/v1/projects/pangu2/buybacks` — 回购事件列表
- `GET /api/v1/projects/pangu2/locker/batches` — 锁仓批次

#### Staking
- `GET /api/v1/projects/pangu2/staking/earned?address=` — 收益
- `GET /api/v1/projects/pangu2/staking/positions?address=` — 仓位
- `GET /api/v1/projects/pangu2/staking/status` — 全局状态

### Admin API（Session Auth + CSRF）

#### Dashboard
- `GET /admin-api/.../dashboard` — KPI 数据
- `GET /admin-api/.../contracts` — 合约注册表

#### 合约注册表 CRUD（SUPER_ADMIN）
- `GET/POST /admin-api/.../contract-registry` — 列表/新增
- `DELETE /admin-api/.../contract-registry/{id}` — 软删除
- `POST /admin-api/.../contract-registry/resync` — 从 config 同步

#### 治理监控（SUPER_ADMIN + OPERATOR）
- `GET /admin-api/.../governance/trading-status` — 交易开关状态
- `GET /admin-api/.../governance/buyback-check` — 回购可行性
- `GET /admin-api/.../governance/oracle-status` — Oracle 状态 (UNINITIALIZED/ACCUMULATING/READY/LIQUIDITY_LOW)
- `GET /admin-api/.../governance/pause-status` — 暂停状态
- `GET /admin-api/.../governance/system-addresses` — 系统地址白名单
- `GET /admin-api/.../governance/deployer-balance` — 部署者 Gas 余额

#### 治理写操作（SUPER_ADMIN）
- `POST /admin-api/.../governance/set-pair` — 开启/关闭交易对
- `POST /admin-api/.../governance/pause` / `unpause` — 暂停/恢复
- `POST /admin-api/.../governance/trigger-buyback` — 触发回购
- `POST /admin-api/.../governance/update-oracle` — 更新 Oracle
- `POST /admin-api/.../governance/release-locker` — 释放锁仓

#### Jobs & Audit
- `GET /admin-api/.../jobs` — 任务列表
- `POST /admin-api/.../jobs/{taskName}/retry` — 重试 (需 Idempotency-Key)
- `GET /admin-api/.../audit-logs` — 审计日志

#### Staking Admin
- `GET /admin-api/.../staking/coverage` — 偿付能力
- `POST /admin-api/.../staking/fund-rewards` ⚠️ 501 NOT_IMPLEMENTED
- `POST /admin-api/.../staking/set-reward-rate` ⚠️ 501 NOT_IMPLEMENTED

### ChainOperatorService（GE-A04 新增）

- 纯 PHP ECDSA + Keccak-256 离线签名
- EIP-155 链重放保护 + low-s 规范化
- 主网写入默认禁止（ALLOW_MAINNET_WRITES=false）
- estimateGas 预检强制通过
- 全部操作 audit_log 记录

---

## 三、DApp 前端（apps/dapp/）

### 路由（3 条）

| 路径 | 名称 | 页面 |
|------|------|------|
| `/` | home | HomePage.vue |
| `/trade` | trade | TradePage.vue |
| `/portfolio` | portfolio | PortfolioPage.vue |

### HomePage — 首页

- **Hero Banner**: 品牌 + 价格/持币人数/流动性（均显示 `—`）
- **Wallet Position 卡片**: 余额 + BNB 估值 + 迷你走势图 + Rewards/Locked/Rank 入口
- **Protocol 参数卡**: 4% 税 / 0.01 BNB 回购 / 60s 间隔
- **Why BGP**: 静态品牌文案
- **Holder Ranking**: 占位（Coming soon）

**数据状态**: 全部动态数据 `—`（等 API 接入）。只连接了 `useWalletStore`。

### TradePage — 交易页

- **市场卡片**: 交易对 + 价格 + 24h High/Low/Volume（均 `—`）
- **图表区**: "Trading not yet activated" 占位，无倒计时
- **交易面板**: Buy/Sell 切换，金额输入，报价详情，提交按钮 disabled
- **交易活动**: 空列表

**关键规则**: 提交按钮永久 disabled，无 `useQuote`/`useMarket`/`useTransaction` composable 接入。

### PortfolioPage — 资产页

- **资产总览**: 余额 + Locked/Available/Locked ratio
- **分发 Donut 图**: 占位 SVG
- **Staking**: 指标 + "Staking not yet available" 禁用按钮
- **My Team**: "Coming soon"
- **Share BGP**: 推荐链接 + 分享（disabled）
- **Buyback Batches**: 空列表

### 核心 Stores & Composables（已实现但未接入页面）

| 模块 | 文件 | 功能 |
|------|------|------|
| Wallet | `useWallet.ts` | wagmi v2 钱包连接 + 网络切换 + 状态机 |
| Data | `useData.ts` | API config/status/contracts 获取 |
| Staking | `useStaking.ts` | 仓位/收益/全局状态 |
| DataStatus | `useDataStatus.ts` | 数据新鲜度自动监测（15s） |
| Quote | `useQuote.ts` | Buy/Sell 报价 + 30s 过期 + AbortController |
| Market | `useMarket.ts` | trading_enabled 30s 轮询 |
| Transaction | `useTransaction.ts` | 完整 Sell 交易生命周期 + Approval 子流程 |
| Staking (feature) | `useStaking.ts` | 5 种链上操作（stake/unstake/earlyUnstake/claimRewards/approveIfNeeded） |

### 共享 UI 组件（packages/ui/）

| 组件 | 功能 |
|------|------|
| Card | 标准/软卡片容器 |
| Button | primary/secondary/text 三级 |
| Tag | demo/locked/open 状态标签 |
| SectionHead | 渐变装饰线 + 标题 |
| Sheet | 半屏浮层 + Teleport |
| BottomNav | 3 tab 底部导航 |
| Toast | 全局提示 |

### 设计令牌（tokens.css）

26 个 CSS 变量：颜色 14 个 + 布局/圆角/阴影。深海军蓝暗色主题，max-width 430px 移动端。

---

## 四、Admin 前端（apps/admin/）

### 路由（8 条，全部需登录）

| 路径 | 名称 | 页面 | 状态 |
|------|------|------|:--:|
| `/login` | login | LoginView | ✅ 真实后端 |
| `/` | overview | OverviewView | ✅ 真实 API |
| `/assets` | assets | AssetsView | ✅ 真实 API |
| `/trades` | trades | TradesView | ⚠️ 零地址查询 |
| `/buyback` | buyback | BuybackView | ✅ 真实 API |
| `/staking` | staking | StakingView | ✅ 部分（写 501） |
| `/dividend` | dividend | DividendView | ⚠️ 合成历史 |
| `/governance` | governance | GovernanceView | ✅ 部分（RBAC 硬编码） |

### Auth 流程

```
LoginView → getCsrfToken() → adminFetch POST /auth/login
→ Session Cookie → Router Guard (checkSession)
→ adminFetch 自动 X-CSRF-TOKEN + 419 重试
```

### 页面详情

| 页面 | API 端点 | 刷新 | 状态 |
|------|----------|:--:|------|
| Overview | config/status/contracts (3) | 30s | ✅ |
| Assets | contracts | 30s | ✅ |
| Trades | wallets/0x0...0/transactions | 单次 | ⚠️ Mock 标记 |
| Buyback | buybacks + locker/batches (2) | 单次 | ✅ |
| Staking | coverage/status/positions/fund/set-rate (5) | 30s+搜索 | ⚠️ 写操作 501 |
| Dividend | epochs/current + dashboard (2) | 60s | ⚠️ 合成历史 |
| Governance | jobs + audit-logs (2) | 15s/30s | ⚠️ RBAC 硬编码 |

### 安全修复（GE-A01~A04）

- ✅ 合约地址 DB 管理 (CRUD + resync)
- ✅ 6 条治理只读端点 (eth_call)
- ✅ 6 条路由补 auth:web 中间件
- ✅ 6 条治理写操作 (eth_sendRawTransaction + 纯 PHP ECDSA 签名)

### Chain Worker（services/chain-worker/）

- **6 个事件流**: TRADE / DIVIDEND / STAKING / LOCKER / SUPPORT / FEE_VAULT
- Fencing Token + Reorg 恢复 + BlockHash Checkpoint
- log_index 唯一定位 + 幂等投影
- 启动验证: chainId + bytecode + deployment block
- 维护租约 (Maintenance Lease)

---

## 五、当前部署状态

| 项目 | 状态 |
|------|:--:|
| 合约部署 | ⚠️ 两套地址并存 (DEPLOYMENT_MANIFEST 旧 vs deployed.ts 新) |
| Bootstrap | ⏳ 未执行 |
| Finalize | ⏳ 未执行 |
| Open Trading | ❌ 未开启 |
| 报价服务 | ⚠️ Mock/UNAVAILABLE |
| Staking 管理写操作 | ⚠️ 501 |
| DApp 数据接入 | ⚠️ 全部 `—` |
| Admin 治理前端 | ⚠️ 部分未接入 /governance/* |
| 本地领先 origin/main | 38 commits |
