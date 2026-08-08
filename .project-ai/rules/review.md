# BingGoPlus — Review Rules

## 本项目审核模式（文档优化优先）

本 MCP 项目「文档优化」以文档策划、修订与审核为主，不是代码实现审核。

权威规则原文：`docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`（ACTIVE）。

### 文档审核硬约束

- 默认只读；除非任务明确授权，不得改代码、跑测试/构建/Migration/RPC/Fork/部署/签名/广播。
- 结论必须绑定路径、版本/Commit、可定位证据；禁止笼统"可能有问题"。
- 证据优先级：链上事实 > 部署 Commit/ABI > 当前仓库机器规范（SQL/OpenAPI/YAML）> 已签署 Decision > 产品/计划文档 > 口头/未验证材料。
- 不得把"文档通过"表述为"代码通过 / 测试通过 / 已部署 / 可上主网"。
- 作者侧状态仅允许 `FIX_READY / INDEPENDENT_RETEST_PENDING` 等；执行 Agent 不得自行把独立 Finding 标为 `CLOSED`。
- Markdown 与机器规范必须同 revision；缺 SQL/OpenAPI/Event/State 时受影响项标 `BLOCKED/UNABLE_TO_VERIFY`，不得用历史 ZIP 补洞。

### 文档严重程度（沿用规则原文）

- P0：错误授权、资金/密钥风险表述、绕过 Gate、把未批准写成已批准
- P1：机器规范与说明冲突、无写入者状态、不可重建 Snapshot、范围越权
- P2：计数/索引漂移、材料不完整、表述歧义但不改安全边界
- P3：措辞润色、可接受偏差

## Go V2 独立审核历史（已完成 10 轮）

| 轮次 | Verdict | 关闭 Finding |
|------|------|------|
| Round1 | Design review baseline | Foundational findings |
| Round2 | P1-DB-01/P1-BRAND-01 closed | P1-DB-02 → further rounds |
| Round3 | Cloud review | P1-R3-01..03 opened |
| Round4 | Cloud review | P1-R3-01..03 → CLOSED; P2-DOC-01 → CLOSED |
| Round5 | BLOCKED (missing machine specs) | Material completeness issue |
| Round6 | Full package review | Round5 issues resolved |
| Round7 | Full package review | Publish failure writer + cancel intent handover |
| Round8 | Full package review | P1-R8-01/P1-R8-02 found |
| Round9 | APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE | P1-R8-01/02 + P1-R4-02 + P1-R6-01 + P2-R6-01/02 = CLOSED |
| Round10 | APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE | P2-R9-01 = CLOSED |

### 已确认独立审核关闭的关键 Finding

- P1-DB-01：Raw Event 可绑定错误 Stream/合约 → `chain_stream_contracts` 固化五列授权绑定
- P1-DB-02：Audit append-only 与运行权限 → Trigger/Audit 边界修复 + Projector/Dividend 工作流闭合（轮次推进）
- P1-BRAND-01：BingGoPlus/PANGU2 与自动回购表述冲突 → 品牌统一 + permissionless trigger
- P1-DB-PRIV-01：Projector 无法写 Raw Event `PROJECTED` → 删除 PROJECTED，改用 versioned receipt
- P1-DB-PRIV-02：Dividend Builder 无固定区块历史输入 → 四个 security_barrier View
- P1-R8-01：当前 Publish Attempt 与唯一 Publish Command 精确绑定；历史失败 Command 不能污染新尝试
- P1-R8-02：Cancellation Request 的 pending-cancel fail-closed 路径闭合
- P2-R9-01：Command=`REJECTED` + Request → `REJECTED`；Command=`CANCELLED` + Request → `CONSUMED`

### Go V2 独立审核复验重点

- Raw Event 无 `PROJECTED`；receipt 集合表达多 projector/version
- Dividend Snapshot 只用历史视图，不用 current 表
- `bgp_projector` / `bgp_dividend` / `bgp_reconciler` 最小权限与 writer boundary
- 产品范围无未批准推荐/佣金
- Mainnet NO-GO；Testnet redeploy FORBIDDEN
- Epoch State YAML 逐边匹配 Trigger；终态不可离；same-state 更新仅限角色拥有字段 + `updated_at`

## Runtime Gate 审核规则（2026-08-08 新增）

### RT-GATE-01 审核要点
- PostgreSQL 16+ 隔离实例确认
- 8 个 LOGIN Role 的集群权限干净（NO SUPERUSER/CREATEDB/CREATEROLE/BYPASSRLS）
- `bgp_migrator` 不与任何运行角色继承
- DDL 0001 + 0002 执行 exit code = 0
- 每个角色的 `SELECT current_user` 精确匹配
- "应该成功"和"必须失败"测试全部通过
- 状态保护反例全部验证

### RT-GATE-02 审核要点
- Primary/Backup RPC chain_id 一致且等于 97
- 固定 evidence block 的 number/hash 在两个 RPC 完全一致
- 所有 11 合约 + Pair 的 runtime code hash 非空且可验证
- `factory.getPair(PANGU2, WBNB)` 返回地址匹配
- 链上角色/暂停/开盘/Oracle/Fee/Locker/Staking 状态 readback 完整
- RPC Secret 不写入任何证据文件

### RT-GATE-03 审核要点
- `backend-go/` 不存在时不得声称 Build 通过
- G0→G1→G2 阶段方案合理，不循环
- Go 精确版本已由人工 pin
- 所有依赖 Decision Record 完整，获 APPROVE_DOWNLOAD
- G1 代码边界清晰（skeleton only，无业务逻辑）

## 代码/合约审核严重程度参考

P0: 资金损失/私钥泄露/权限全绕过  
P1: 功能不可用/Data 不一致/Fail Open  
P2: 边界值错误/配置缺失  
P3: 命名/注释/可接受偏差

### 合约修复阶段审核 (S0-S9)
- 双轮审核 (Pre-Fix + Post-Fix) + 校对 Agent
- 结论: APPROVED_CODE_ONLY / CHANGES_REQUIRED / BLOCKED
- 不得修改冻结经济参数

## 信息来源
- `docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`
- `docs/current/go-backend-v2/`（README, 09, 22, 23, runtime-gate/）
- `docs/current/PRODUCT_PLANNING.md`
- `artifacts/BINGGOPLUS_GO_V2_ROUND6_COMPLETE_PACKAGE_20260807_V1/`
