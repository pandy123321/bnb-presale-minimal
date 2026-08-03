# Task索引与Gate

```text
Document ID: PANGU2-FB-TASK-INDEX-1.0
Version: V1.0
Status: PLANNING_BASELINE
Project ID: PANGU2
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Observed Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Target Environment: LOCAL / CI / BSC_TESTNET / STAGING
BSC_MAINNET: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
Prepared At: 2026-08-01
```

> `Observed Base SHA` 是本文件生成时观察值。每个Task开始前必须重新读取Base Branch Tip并固定 `Task Start Base SHA`。

## 1. 任务清单

| Task ID | Title | Stream | Planning Status | File |
|---|---|---|---|---|
| P2-A01 | Admin工程骨架与布局 | admin | READY_AFTER_X02 | `tasks/admin/P2-A01.md` |
| P2-A02 | Admin认证与RBAC UI | admin | BLOCKED_BY_A01_B02 | `tasks/admin/P2-A02.md` |
| P2-A03 | Dashboard、Registry与交易监控 | admin | BLOCKED_BY_A01_B03_B05 | `tasks/admin/P2-A03.md` |
| P2-A04 | Epoch、Jobs与审计页面 | admin | BLOCKED_BY_A02_B06_B07 | `tasks/admin/P2-A04.md` |
| P2-A05 | Admin Closeout与E2E | admin | BLOCKED_PREVIOUS | `tasks/admin/P2-A05.md` |
| P2-B01 | Laravel API与Horizon工程骨架 | backend | READY_AFTER_X02 | `tasks/backend/P2-B01.md` |
| P2-B02 | 钱包签名认证与Session | backend | BLOCKED_BY_B01 | `tasks/backend/P2-B02.md` |
| P2-B03 | Contract Registry与System Status | backend | BLOCKED_BY_B01 | `tasks/backend/P2-B03.md` |
| P2-B04 | Quote与用户交易API | backend | BLOCKED_REQUIREMENT | `tasks/backend/P2-B04.md` |
| P2-B05 | Chain Worker与交易投影 | backend | BLOCKED_SCHEMA | `tasks/backend/P2-B05.md` |
| P2-B06 | Dividend、Buyback与Locker读模型 | backend | BLOCKED_REQUIREMENT | `tasks/backend/P2-B06.md` |
| P2-B07 | Admin RBAC、Jobs与审计 | backend | BLOCKED_BY_B02_B06 | `tasks/backend/P2-B07.md` |
| P2-F01 | DApp工程骨架与设计系统 | dapp | READY_AFTER_X02 | `tasks/dapp/P2-F01.md` |
| P2-F02 | 钱包连接与Network状态 | dapp | BLOCKED_BY_F01 | `tasks/dapp/P2-F02.md` |
| P2-F03 | 生成API Client与全局数据状态 | dapp | BLOCKED_BY_F01_X02 | `tasks/dapp/P2-F03.md` |
| P2-F04 | 交易页面与Quote展示 | dapp | BLOCKED_BY_F02_F03 | `tasks/dapp/P2-F04.md` |
| P2-F05 | Approval、Signature与交易状态机 | dapp | BLOCKED_ABI | `tasks/dapp/P2-F05.md` |
| P2-F06 | 分红、托底与我的页面 | dapp | BLOCKED_API | `tasks/dapp/P2-F06.md` |
| P2-F07 | DApp Closeout与E2E | dapp | BLOCKED_PREVIOUS | `tasks/dapp/P2-F07.md` |
| P2-I01 | Local Full Stack编排 | integration | BLOCKED_FOUNDATION | `tasks/integration/P2-I01.md` |
| P2-I02 | Mock纵切片端到端 | integration | BLOCKED_X_B_F_A | `tasks/integration/P2-I02.md` |
| P2-I03 | Anvil合约与应用集成 | integration | BLOCKED_PB_S1 | `tasks/integration/P2-I03.md` |
| P2-I04 | BSC_TESTNET完整闭环 | integration | BLOCKED_INTEGRATION_GATE | `tasks/integration/P2-I04.md` |
| P2-I05 | STAGING发布与PB-S6 Closeout | integration | BLOCKED_I04 | `tasks/integration/P2-I05.md` |
| P2-X01 | 共享OpenAPI、错误码和状态机候选 | shared | READY_AFTER_PB-S0 | `tasks/shared/P2-X01.md` |
| P2-X02 | 生成API Types、Client与Mock Server | shared | BLOCKED_BY_X01 | `tasks/shared/P2-X02.md` |
| P2-X03 | 共享契约测试与变更控制 | shared | BLOCKED_BY_X02 | `tasks/shared/P2-X03.md` |

## 2. 当前可启动分类

```text
当前GO:
- 仅文档审阅、治理基线采用和本并行开发包落库准备。

治理和工具链关闭后可GO:
- P2-X01
- P2-X02
- P2-B01
- P2-F01
- P2-A01

可Mock并行、LIVE受阻:
- P2-B04
- P2-F04
- P2-F05部分UI状态
- P2-B06
- P2-F06
- P2-A04

BLOCKED:
- 依赖PB-S1 ABI/Event或Signed Parameter Freeze的LIVE任务；
- BSC_TESTNET Integration；
- BSC_MAINNET全部任务。
```

## 3. Task Start Gate规则

每个任务必须单独固定：

- Task Start Base SHA；
- Current Base Branch Tip SHA；
- Spec/Ruleset/Workflow/Lockfile SHA；
- Allowed/Forbidden Paths；
- Active Decision与Parameter Freeze；
- Dependencies；
- Required Checks；
- Duplicate Task/PR/Finding；
- Closure Conditions。

本索引不是Task Start Gate。
