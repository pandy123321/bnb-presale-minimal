# PANGU2 / 文档优化 — Review Rules

## 本项目审核模式（文档优化优先）

本 MCP 项目「文档优化」以文档策划、修订与审核为主，不是代码实现审核。

权威规则原文：`docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`（ACTIVE）。

### 文档审核硬约束

- 默认只读；除非任务明确授权，不得改代码、跑测试/构建/Migration/RPC/Fork/部署/签名/广播。
- 结论必须绑定路径、版本/Commit、可定位证据；禁止笼统“可能有问题”。
- 证据优先级：链上事实 > 部署 Commit/ABI > 当前仓库机器规范（SQL/OpenAPI/YAML）> 已签署 Decision > 产品/计划文档 > 口头/未验证材料。
- 不得把“文档通过”表述为“代码通过 / 测试通过 / 已部署 / 可上主网”。
- 作者侧状态仅允许 `FIX_READY / INDEPENDENT_RETEST_PENDING` 等；执行 Agent 不得自行把独立 Finding 标为 `CLOSED`。
- Markdown 与机器规范必须同 revision；缺 SQL/OpenAPI/Event/State 时受影响项标 `BLOCKED/UNABLE_TO_VERIFY`，不得用历史 ZIP 补洞。

### 文档严重程度（沿用规则原文）

- P0：错误授权、资金/密钥风险表述、绕过 Gate、把未批准写成已批准
- P1：机器规范与说明冲突、无写入者状态、不可重建 Snapshot、范围越权
- P2：计数/索引漂移、材料不完整、表述歧义但不改安全边界
- P3：措辞润色、可接受偏差

## 代码/合约审核参考（非本项目默认）

若任务明确要求对照实现，可参考下列严重程度，但仍以文档规则为准：

P0: 资金损失/私钥泄露/权限全绕过  
P1: 功能不可用/Data 不一致/Fail Open  
P2: 边界值错误/配置缺失  
P3: 命名/注释/可接受偏差

### 合约修复阶段审核 (S0-S9)

- 双轮审核 (Pre-Fix + Post-Fix) + 校对 Agent
- 结论: APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED
- 不得修改冻结经济参数

### Go V2 规划复验重点

- Raw Event 无 `PROJECTED`；receipt 集合表达多 projector/version
- Dividend Snapshot 只用历史视图，不用 current 表
- `bgp_projector` / `bgp_dividend` / `bgp_reconciler` 最小权限与 writer boundary
- 产品范围无未批准推荐/佣金
- Mainnet NO-GO；Testnet redeploy FORBIDDEN

## 信息来源

- `docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`
- `docs/current/go-backend-v2/`
- `docs/current/PRODUCT_PLANNING.md`
- `artifacts/BINGGOPLUS_GO_V2_ROUND6_COMPLETE_PACKAGE_20260807_V1/`
