# BingGoPlus Flap F0-F11 执行计划

状态：`V6_REVIEW_CHANGES_REQUIRED / V7_P1_REMEDIATION_FIX_READY / INDEPENDENT_RETEST_PENDING`

## 1. 阶段总览

| 阶段 | 目标 | 允许修改 | 退出条件 |
|---|---|---|---|
| `F0` | 产品转向、范围、经济继承、退役矩阵、执行计划 | 文档/上下文/规则 | 独立审核 + Owner Freeze |
| `F1` | Flap 官方地址、ABI、selector、默认值、runtime hash、依赖准入 | 文档/ABI Evidence | Baseline Review APPROVED |
| `F2` | DB/API/Event/State/RBAC/Signer/参数机器规范冻结 | 文档 + 机器规范，不写业务实现 | 独立审核 + Owner Freeze |
| `F3` | Flap Chain Acquisition、Indexer 与只读模型 | Go + 已冻结 Migration | 链身份、Cursor、Reorg、Raw Event 与确定性 Read Model Gate |
| `F4` | Launch Workflow 与 API | Go | Draft/Validation/Approval/Intent、Admin/Public API 与幂等 Gate；不签名 |
| `F5` | Signer 与 Transaction Execution | Go + 隔离签名边界 | Allowlist、预算、Nonce、签名、广播、Receipt/Event 绑定 Gate；实际测试网链写仍需单独授权 |
| `F6` | Admin Launch Console 与 Flap Native MVP | Admin/DApp + Go 集成 | 后台发币、状态/Token 地址/Flap 链接和最小公开读面 Code Review；不含 BGPlus 自建合约 |
| `F7` | BGPlusVaultFactory + 五桶 RevenueVault | `contracts-flap` | 独立 Solidity 审核；完整资金目的地/会计 Gate；不含部署授权 |
| `F8` | Buyback/Burn、Locker、Dividend/Top100、Token Vesting 合约 | `contracts-flap` + 设计同步 | 独立 Solidity 审核；不含部署授权 |
| `F9` | BGPlus Vault Admin/Job/Dividend Builder 集成 | Go/Admin | 端到端代码审核；不含链上部署授权 |
| `F10` | 通用 Staking | `contracts-flap` + Go/Admin/DApp 集成 | 独立 Solidity 审核 + 偿付/本金隔离 Gate；不含部署授权 |
| `F11` | Legacy PANGU2 Cutover/Retirement | 迁移、路由、页面与运行配置 | 独立 Cutover Review + Runtime/Deployment/Rollback Gates |

## 2. F0 — 产品转向冻结

交付：文档 27～32、V6 决策/自审/提审身份 44～46、旧计划 `SUPERSEDED` 标记、Current Authority、Rules/Context 同步。

禁止：Go、SQL、OpenAPI、前端、Solidity、RPC、测试、构建、迁移、签名和部署。

退出：

```text
F0_DOCUMENT_REVIEW = APPROVED
EXECUTOR_ADJUDICATION = ACCEPTED
RESPONSIBLE_OWNER_FREEZE = SIGNED
F1_ENTRY_AUTHORIZED = YES
```

## 3. F1 — Flap 外部协议基线

必须从 Flap 官方文档和 BSC Testnet 链上固定：Portal、VaultPortal、官方 Split Vault Factory、Guardian、ABI、selector、事件、默认值、runtime bytecode hash、部署区块和资料时间。

同时完成：

- Flap/示例/SDK 的 Reference/Adoption 分类；
- License、NOTICE、SBOM、TCO 与下载批准；
- 精确参数能力矩阵；
- ABI 漂移检测和升级/退役策略；
- 禁止使用 `Factory.createToken()` 等未经当前 ABI 证明的旧假设。
- 精确确认 `creator / payer / msg.sender / initial buyer`，确保 Admin Wallet 模式不会伪造终端用户身份；
- 将 F0 中 `DOCUMENTED_BY_FLAP / PENDING_F1_RUNTIME_BASELINE` 的能力逐项裁决为 `SUPPORTED / UNSUPPORTED / DEFAULTED`；
- 若官方 Split Vault 不满足当前测试网基线，冻结 Standard/Tax-without-Vault 的 Native MVP fallback，不让 Split Vault 单点阻塞后台发币。
- 验证普通 Tax、开盘保护高税率、Curve 阶段与 DEX Migration 后的实际征税位置和兼容性；`15 minutes / 3000 bps` 未被证明前不得进入表单；
- 验证 creator allocation、initial buy 和普通转账，判断团队/投资人/项目储备 Token 是否能真实预充值到 Vesting；无法证明则标 `UNSUPPORTED`；
- 验证 Tax Revenue 实际资产和 Vault 入账路径，确认 Staking Bucket 是否能在迁移后安全兑换为绑定 Token。

## 4. F2 — 机器规范冻结

必须同一 Revision 输出：

```text
SQL schema
runtime privileges
OpenAPI 3.1
Event Catalog
State Machines
RBAC Matrix
Parameter Catalog machine form
Signer allowlist
Failure/Reorg/Idempotency rules
```

F2 不写业务实现。任何表、API、状态边、writer、角色或参数可变性冲突都阻断进入 F3。

## 5. F3-F6 — Flap Native MVP

F3：真实只读 RPC、Chain ID、Head/Block/Log、Cursor、Lease、Confirmation、Reorg、Portal 事件，并把同交易多事件确定性合并为 Token、Curve、Tax、Vault、Migration、Pool 与 Revenue 只读模型。F3 不创建 Launch Command、不签名、不广播。

F4：实现 Admin Launch Draft、Validation、Approval、Transaction Intent、Admin/Public API、状态机、RBAC、幂等和审计；只生成受冻结参数约束的待执行意图，不持有私钥、不签名、不广播。

F5：实现隔离的签名与交易执行路径，验证 target/selector/value/calldata/request hash、Signer allowlist、预算、Nonce、超时、重试、Receipt/Event 与 Launch Attempt 精确绑定。Admin Wallet 仍是 MVP 责任身份；任何真实测试网签名/广播必须另获人工授权。

F6：交付 Admin Launch Console 和 Flap Native MVP：后台创建/审批/执行视图、Token 地址、交易状态和 Flap 链接，并提供最小 Public Read API/DApp 读面。Curve 阶段只使用已验证的 Flap 交易入口，迁移后只使用已确认 Pool；数据不完整返回 `UNAVAILABLE`。F6 不包含 RevenueVault、Dividend、Buyback、Locker 或 Staking 自建合约。

F6 是 Native MVP 完整交付点；F4/F5 可以形成内部可审核能力，但不得宣传为用户可用的一键发币产品。

## 6. F7-F10 — BGPlus 扩展

F7 只开发 Factory/RevenueVault，并冻结 Guardian 最小权限、不可升级策略、全部资金目的地址、Bucket 授权动作和下列累计会计：当前 liability、Dividend funding、Buyback spend、Staking reward swap spend、Marketing/Operations payment、staking reward token received 与 rounding carry。默认分桶为 30/25/20/15/10，Launch 前可调、合计 10000，确认后不可改。BGPlusVaultFactory V1 创建费与 Revenue Commission 必须为 0，不得成为第六资金出口。

F8 开发 DEX Migration 后回购/销毁、可选 Locker、所有有效持有人基础 Merkle 分红、Top 100 额外奖励和独立 Token Vesting。不得恢复成本基础税或 35/25/25/15 四档；Top 100 必须按固定快照、有效持币量降序和地址升序打破同额，并按榜内有效持币量同比例分配额外池。所有 custody 地址余额必须排除；Staking principal 只按受益人计一次；Vesting V1 未释放 Token 不参与分红或排名。

F9 集成 Admin、Reconciler、任务和 Dividend Builder。平台 Signer 若未单独通过 Gate，仍保持 Admin 钱包模式。

F10 单独开发通用 Staking。Staking 使用独立 Pool，奖励来源为 Staking BNB Bucket 在 `MIGRATED/ACTIVE` 后受控兑换的绑定 Token，并允许额外预充值；本金/奖励隔离。EarlyUnstake 罚金和被没收奖励只能回到同 Pool available Reward Reserve，不能转给外部地址或重复记作入账。不得与 Legacy Cutover 合并为同一 Commit、审核包或回滚单元。

F7-F10 是责任人要求“发币和重做都要”的正式产品路线，不是 Native MVP 的阻断项，也不是可以被执行 Agent自行删除的可选想法。F6 通过后必须暂停在扩展边界，完成 F7 Extension Entry Review 与 Responsible Owner/Security Scope Authorization；只有 `F7_ENTRY_AUTHORIZED = YES` 才能开始 F7。F7～F10 之后仍逐阶段实施，每一阶段都需单独设计、安全审核与部署授权。

```text
F6_TO_F7_AUTO_ADVANCE = FORBIDDEN
F7_ENTRY_AUTHORIZED = NO_BY_DEFAULT
F7_ENTRY_REQUIRES = EXTENSION_ENTRY_REVIEW + RESPONSIBLE_OWNER_SECURITY_SCOPE_AUTHORIZATION
```

## 7. F11 — Legacy Cutover/Retirement

F11 只处理 PANGU2 页面、API、后台写入口和运行服务的历史只读/下线，不开发新金融合约。必须在 Flap 替代读路径、Admin 路径、Legacy 数据导出、写入口撤销、回滚方案和独立 Cutover 审核全部通过后执行；不删除历史证据。F11 不得与 F10 Staking 共用 Commit、审核或部署 Gate。

## 8. 每阶段自动审核

```text
Stage Complete
-> Stop Next-Stage Coding
-> Self Review
-> Single Commit
-> Complete Diff + Manifest + SHA-256
-> Deliver package and prompt to user for manual independent review
-> Wait Final Verdict
-> Executor Adjudication Per Finding
-> Fix Only CONFIRMED Findings
-> Re-Review Until APPROVED
-> Register Gate
-> Auto Advance Only To The Already Frozen Next Stage
```

外部报告必须对每条 Finding 给出文件/行号或对象、证据、根因、影响、具体修改步骤、约束、验收与回归检查。只报问题不给解决方案时：

```text
REVIEW_COMPLETENESS = INCOMPLETE
NEXT_STAGE_AUTHORIZATION = NO
```

执行 Agent 读取外部结论后必须二次判断：`CONFIRMED / REJECTED_WITH_EVIDENCE / DUPLICATE / NEEDS_MORE_EVIDENCE / SCOPE_EXPANSION_REQUIRED`。错误 Finding 不执行，并写入下一次提审的 Adjudication。

## 9. 自动推进与人工确认

范围内、下一阶段已冻结、审核和裁决全部通过时自动继续，不重复请求人工确认。

唯一阶段边界例外：`F6 -> F7` 不适用默认自动推进。F7 首次进入自建金融 Solidity 域，即使已列入必做路线，也必须先完成独立 Extension Entry Review 和责任人/安全范围授权；这只控制进入时间，不把 F7～F10 降为 Optional。

以下动作始终单独人工授权：

- F0/F2 Responsible Owner Freeze；
- 新 Solidity 部署；
- Flap Testnet Launch 真正签名/广播；
- 平台 Signer 启用；
- 生产数据库迁移；
- Mainnet（当前永久 NO-GO）；
- 任何超出参数目录、阶段路径和经济边界的改动。

## 10. 当前状态

```text
CURRENT_STAGE = FLAP-F0
V6_REVIEW = CHANGES_REQUIRED / REMOTE_EVIDENCE_GATE_PASS
F0_IMPLEMENTATION = DOCUMENTS_ONLY_V7_P1_REMEDIATION_FIX_READY
F0_INDEPENDENT_REVIEW = V7_INDEPENDENT_RETEST_PENDING
F0_LOCAL_ISOLATED_COMMIT = COMMIT_CONTAINING_DOC_49 / SEE_PACKAGE_COMMIT_ID
F0_SUBMISSION_CONTEXT = 49_FLAP_F0_V7_SUBMISSION_CONTEXT.md
F0_REMOTE_PUSH = USER_MANUAL_PENDING
F1_ENTRY_AUTHORIZED = NO
EXTERNAL_REVIEW_SUBMISSION = USER_MANUAL
AUTO_ADVANCE = PAUSED_PENDING_REVIEW_AND_OWNER_FREEZE
F6_TO_F7_AUTO_ADVANCE = FORBIDDEN
F7_ENTRY_AUTHORIZED = NO_BY_DEFAULT
FLAP_CODE = NOT_STARTED
NEW_SOLIDITY = NOT_STARTED
CHAIN_WRITE = NO
BSC_MAINNET = NO-GO
```

V7 Commit 无法在同一 Commit 内写入自身最终 SHA；包内 `COMMIT_ID.txt` 与 `COMMIT_METADATA.txt` 是当前提交身份的权威机器绑定。V6 或更早的 Package/Commit 都不能授权当前修订 Freeze。
