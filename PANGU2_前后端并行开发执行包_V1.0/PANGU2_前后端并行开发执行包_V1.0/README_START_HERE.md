# PANGU2前后端并行开发执行包

```text
Document ID: PANGU2-FB-SYNC-PACK-1.0
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

## 1. 目标

在不破坏盘古2治理和参数边界的前提下，同步开发：

- Laravel API与业务Job；
- TypeScript Chain Worker；
- 用户DApp；
- 运营Admin；
- 共享OpenAPI、类型、状态机和Mock Server；
- LOCAL、CI、BSC_TESTNET和STAGING联调。

## 2. 核心方法

```text
治理与工具链
→ 共享Schema和Mock
→ 前端/后端骨架并行
→ 业务纵切片并行
→ 合约ABI/Event接入
→ BSC_TESTNET端到端
```

前端不自行实现税率、盈利判定、排名或可领取金额公式。后端不代替用户签名，不把未批准合约规则写成正式业务逻辑。

## 3. 开发流

| Track | 范围 | 主要目录 |
|---|---|---|
| Shared | OpenAPI、API Types、状态机、Mock、错误码 | `packages/**`, `docs/schemas/**` |
| Backend | Laravel API、Horizon业务Job | `services/api/**` |
| Chain | 原始链上事实、Reorg、Cursor | `services/chain-worker/**` |
| DApp | 用户钱包、交易、分红、托底、我的 | `apps/dapp/**` |
| Admin | RBAC、仪表盘、Epoch、任务、审计 | `apps/admin/**` |
| Integration | Contract/API/UI/Testnet E2E | `docs/evidence/**`, 各模块测试 |

## 4. 立即执行顺序

1. 完成并合并V3.1/V1.1治理基线任务；
2. P2-X01固定共享接口候选；
3. P2-X02建立Mock Server与生成类型；
4. 后端P2-B01和前端P2-F01、P2-A01并行；
5. 按纵切片逐项联调；
6. PB-S1合约ABI/Event可用后替换Mock链上源；
7. P2-I04完成BSC_TESTNET闭环。

## 5. 当前门控

```text
Document Readiness: READY
Parallel Development Plan Readiness: READY
Product Task Start Gate: NEEDS_CONFIRMATION
Reason:
- V3.1/V1.1基线需先进入仓库并固定SHA；
- 工具链、Lockfile和LOCAL/CI未关闭；
- Parameter Freeze与Quote Profile尚未完整签署。
```

因此本包是可执行Task Spec集合，但每个Task仍需项目协调Agent在实际Base SHA下单独输出 `Task Start Gate: GO`。

## 6. 使用入口

- 总计划：`docs/01_前后端并行开发总计划.md`
- 依赖图：`docs/02_阶段依赖与并行矩阵.md`
- 共享契约：`docs/03_共享接口与Schema基线.md`
- 后端计划：`docs/04_后端与ChainWorker开发计划.md`
- DApp计划：`docs/05_DApp开发计划.md`
- Admin计划：`docs/06_Admin开发计划.md`
- 联调验收：`docs/07_联调测试与验收计划.md`
- Task索引：`docs/08_Task索引与Gate.md`
- Cursor提示词：`prompts/`
