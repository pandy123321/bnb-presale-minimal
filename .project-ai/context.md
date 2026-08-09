# BingGoPlus — Project Context

## 当前权威信息（F0 冻结候选；Flap 运行事实待 F1）

### 项目目标
以 Flap 为唯一发币入口的多 Token Launch 与经济扩展平台（品牌 BingGoPlus / BGP）。F0 仅冻结三个计划模式：Flap Standard、Flap Tax + 官方 Split Vault、Flap Tax + 自建 BGPlus Vault；它们都不是已实现能力，必须经 F1 地址/ABI/runtime/行为基线后才能标记为支持。V6 Owner 经济模型要求尽量保留旧机制的业务目的：候选默认 5% Token Tax，按 30% Dividend、25% Buyback/Burn、20% Staking、15% Marketing、10% Operations 分桶；所有有效持有人基础分红，Top100 另获确定性额外池；回购默认 100% 销毁；Staking 由税收桶迁移后受控兑换奖励 Token并允许外部预充值；团队/投资人/项目储备使用独立预充值 Vesting；候选开盘保护为旧真实值 15 分钟/30% 税。所有参数只在 Launch 前可调，确认后冻结，且均受 F1/独立 Solidity Gate 约束。PANGU2 CostBasis、动态盈利税、专用 Router/Settlement、Whitelist、Top100 35/25/25/15 四档和专用 Staking 实现永久退出新产品。

### 当前阶段
PANGU2 合约已部署 BSC Testnet（`3ef50b6`），继续作为 Legacy Read-Only 历史证据，不修改、不重部署。Laravel 代码冻结；Go 仍是唯一目标后端。当前产品实现暂停在 Flap F0 Change Gate，旧 G2-G9 不再是当前执行主线。

**当前 Flap Change Gate**：

| Gate | 状态 |
|------|:--:|
| FLAP-F0 文档冻结候选 | `V5_CONTENT_APPROVAL_SUPERSEDED / V6_ECONOMIC_CHANGE_FIX_READY / INDEPENDENT_RETEST_PENDING` |
| F1 Flap 合约/ABI Baseline | `NOT_AUTHORIZED` |
| Flap Go 实现 | `NOT_STARTED` |
| 新 Solidity | `NOT_STARTED` |
| 外部审核提交 | `USER_MANUAL` |

`backend-go/`、PostgreSQL、Admin 和 DApp 作为技术地基保留。当前工作区存在未审核的 PANGU2 G2/跨阶段候选文件，不计为 Flap 能力，也不得混入 F0 提审包。

### 支持网络
- BSC Testnet (Chain 97) — 当前部署网络
- BSC Mainnet (Chain 56) — NO-GO

### 全局硬约束
- BSC_MAINNET_DEPLOYMENT: NO-GO
- Automatic Merge / Push / Deployment: FORBIDDEN
- OpenTrading 不得被 CI/部署脚本自动调用
- 实现 Agent 不可自行批准自己
- PANGU2 参数不可修改；Flap 参数只允许按 F0 参数目录和生命周期设置
- 合约已部署不可升级

### 合约部署状态（BSC Testnet）

| 阶段 | 状态 |
|------|:--:|
| Deploy | ✅ 已广播 |
| Bootstrap | ✅ 已广播 |
| Finalize | ✅ 已广播 |
| OpenTrading | ✅ 已广播 |
| 链上 readback (Legacy RT-GATE-02) | `BLOCKED_EVIDENCE / INDEPENDENT_RETEST_PENDING`；10/10 Bytecode 已验证不等于技术 Gate PASS，Owner 风险接受不替代运行证据 |

### 合约功能现状

全部已实现：Launch Protection 30% 税、Fee Whitelist 0% 税、Oracle TWAP、0.01 BNB 回购、Staking 1-730 天、Dividend 前 100 名分红。8 合约 admin renounce 已确认。

### 合约修复

| 修复号 | Finding | 状态 |
|:--:|------|:--:|
| F-2 | Claim→EarlyUnstake 绕过奖励没收 | ✅ 已提交 `c0aeac7` |
| F-3 | 没收奖励未返还 reserve | ✅ 已提交 `6f2f475` |
| F-1 | Whitelist 零税 credit(0) 回滚 | ⏳ 待执行 |
| F-4 | Epoch claimStart 前可取消 | ⏳ 待执行 |

### Legacy DApp 前端 V7.1（历史完成）

3 页路由和当前动态数据 `—` 属于 PANGU2 Legacy 状态，不代表 Flap 产品完成。Flap Native MVP 的 Admin Console、最小 Public Read API 与 DApp 读面统一在 F6 交付。

### Flap 主线状态

Flap 已由设计支线改为产品主线：

- `FLAP_STANDARD = CANDIDATE_PENDING_F1_BASELINE`：Portal 普通 Token 候选；
- `FLAP_TAX_SPLIT = MVP_CANDIDATE_PENDING_F1_BASELINE`：VaultPortal + 官方 Split Vault 候选优先路径；
- `FLAP_TAX_BGPLUS = REQUIRED_EXTENSION_PENDING_F1_AND_SOLIDITY_GATES`：VaultPortal + 自建 Factory/Vault 必做扩展路线，承载五桶经济循环；
- `F3 = CHAIN_ACQUISITION_INDEXER_READ_MODEL`；
- `F4 = LAUNCH_WORKFLOW_AND_API`；
- `F5 = SIGNER_AND_TRANSACTION_EXECUTION`；
- `F6 = ADMIN_LAUNCH_CONSOLE_AND_NATIVE_MVP`；
- F0-F11 为当前阶段计划；F8 同时包含 Buyback/Burn、Dividend/Top100 与独立 Vesting，F10 只做税收奖励型通用 Staking，F11 单独执行 Legacy Cutover；旧 G2-G9 对当前执行已被取代；
- `F6_TO_F7_AUTO_ADVANCE = FORBIDDEN`，F7 必须先通过 Extension Entry Review 和责任人/安全范围授权；
- PANGU2 Full Suite 新部署已取消；现有 PANGU2 仅保留历史。

当前只允许 F0 文档、规则和上下文冻结，不允许 Go、SQL、OpenAPI、前端、Solidity、签名或部署。详见文档 27～32。

---

## 待确认

| # | 事项 |
|---|------|
| 1 | V6 经济模型独立文档审核与执行方二次裁决 |
| 2 | `pd123` 在 V6 审核通过后完成 F0 Responsible Owner Freeze |
| 3 | F1 固定 Portal/VaultPortal/Split Vault/Guardian 地址、ABI、selector、默认值和 bytecode hash |
| 4 | F2 冻结新 Schema/OpenAPI/Event/State/RBAC/Signer 与参数机器规范 |

---

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/*/97/run-latest.json
- apps/dapp/src/features/wallet/deployed.ts
- backend-go/（G1 审核基线 28 文件；当前工作区包含未审核候选变更）
- docs/current/go-backend-v2/27～46（当前 Flap F0、历史裁决与 V6 经济模型提审身份）及历史 runtime-gate
- docs/current/RULES_MASTER.md
