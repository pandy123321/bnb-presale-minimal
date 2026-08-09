# BingGoPlus Flap F0 V2 外部审核二次裁决

状态：`PARTIAL_ACCEPTANCE / CORRECT_FINDINGS_FIX_READY / EVIDENCE_GATE_OPEN`

```text
REVIEW_ID = N/A_USER_MANUAL
REVIEW_ARTIFACT_ID = attachment/72a1137e-6a6b-4477-adbc-dcb36e9ccd8b/pasted-text.txt
REVIEW_REPORT_SHA256 = f4aef98df714cb3956d07e40ec60ac5f602a17f6ce54398683553e3a2b599d8b
REVIEW_TIMESTAMP = NOT_PROVIDED_BY_REVIEW_REPORT
REVIEWER_IDENTITY = UNKNOWN_NOT_CLAIMED
ORIGINAL_VERDICT = BLOCKED
ORIGINAL_CONTENT_ASSESSMENT = CHANGES_REQUIRED
ADJUDICATION_STATUS = PARTIAL
F1_ENTRY_AUTHORIZED = NO
BSC_MAINNET = NO-GO
```

本记录执行“外部报告不是自动授权”的规则。每条 Finding 必须与责任人已给出的产品方向、本地文件和可复核的 Flap 官方资料重新核对；只有正确部分进入修订。

## 1. 责任人方向证据

当前会话中责任人 `pd123` 明确要求：

```text
“在现在这个项目的基础上直接转做 Flap”
“发币和重做都要”
“可以在后台直接调用 Flap 的接口或合约发币”
“尽可能保留现状的经济模型结构，参数可以调整”
```

因此下列方向没有得到授权：

```text
NEW_FLAP_PROJECT = INDEPENDENT_FROM_CURRENT_PROJECT
EXECUTION_MODE = USER_WALLET_REPLACES_ADMIN_WALLET
BGPLUS_EXTENSIONS = OPTIONAL_AND_MAY_BE_DROPPED
```

## 2. Finding 裁决矩阵

| Finding | 外部结论 | 二次判定 | 实际动作 |
|---|---|---|---|
| `P1-01` | 改成与现有 BGPlus/PANGU2 完全独立的新项目 | `REJECTED_WITH_EVIDENCE` | 不执行项目拆分；在文档 27 固化“当前项目原地转向”责任人原始输入 |
| `P1-02` | 用普通用户钱包自助发币取代 Admin Wallet | `REJECTED_WITH_EVIDENCE` | 保留后台 Admin Wallet MVP；接受其中身份语义风险，要求 F1 核对 `creator/payer/msg.sender/initial buyer`，禁止伪造用户创建者 |
| `P1-03` | `.project-ai` 把 Legacy RT02/RT03 错写为全部 PASS | `CONFIRMED` | 修正 context、glossary、目录 README 和规则语义；当前 Flap 只有 F0，F1 未授权 |
| `P1-04` | RevenueVault 资金目的地和会计不完整 | `CONFIRMED` | 补齐五个 Bucket 的 Destination、动作、触发者、冻结时点、流出类型、累计会计和失败回滚不变量 |
| `P2-01` | 没有独立 F0 Commit/Diff，按项目规则必须 BLOCKED | `CONFIRMED_BLOCKING_EVIDENCE` | 不伪造 Commit；内容修订完成后仍须安全隔离单一 F0 Commit、完整 Diff 和新包，当前保持 Gate Open |
| `P2-02` | Flap 能力在 F1 前写得过实 | `PARTIALLY_CORRECT` | 官方文档事实保留，但统一标为 `DOCUMENTED_BY_FLAP / PENDING_F1_RUNTIME_BASELINE`；Split MVP 改为 Candidate，并增加 Standard/Tax fallback |
| `P2-03` | F10 同时含 Staking 和 Legacy Cutover | `CONFIRMED` | F10 只做通用 Staking；新增 F11 只做 Legacy Cutover，禁止共用 Commit、审核、部署和回滚 |
| `P2-04` | 手动审核仍把外部任务 ID 当必填 | `CONFIRMED` | ID 改为 `<id> / N/A_USER_MANUAL`，增加 Artifact ID、报告 SHA-256、时间和 Reviewer Identity |
| Product Scope | F7-F10 自建扩展应全部降为可选 | `REJECTED_WITH_EVIDENCE` | 保持为 Native MVP 后的正式必做路线；明确不阻塞 F5/F6，也不得由执行 Agent自行删除 |
| Outer ZIP SHA | 审核时没有提交方预声明 Hash | `PARTIALLY_CORRECT_OPERATIONAL` | 外层 Hash 必须作为独立 companion `.zip.sha256` 与 ZIP 一起手动上传；不得在 ZIP 内做自引用 Hash |

## 3. Flap 外部事实核对

2026-08-09 重新读取 Flap 官方开发文档，确认：

- Portal 是核心 Launch 入口，VaultPortal 在 Portal 上增加 Vault-backed Tax Token 流程；
- Vault Factory V2 提供 `vaultDataSchema()`；
- 官方 Registered Vault 页面记录 BNB Testnet Split Vault、1～10 个非零唯一收款人、BPS 合计 10000；
- 当前 BNB Testnet Portal/VaultPortal 地址和版本仍必须在 F1 通过链上 runtime/ABI/selector/receipt 重新绑定，网页内容不能替代运行基线。

参考：

- https://docs.flap.sh/flap/developers/basic-and-mechanism/portal-vs-vaultportal
- https://docs.flap.sh/flap/developers/token-launcher-developers/registered-vaults
- https://docs.flap.sh/flap/developers/vault-developers/vault-and-vaultfactory-specification
- https://docs.flap.sh/flap/developers/deployed-contract-addresses

因此 `P2-02` 不是“这些能力没有证据”，而是“官方文档证据存在，但尚未完成本项目 F1 测试网 bytecode/ABI/runtime baseline”。

## 4. 已修复对象

```text
docs/current/go-backend-v2/27_FLAP_PRODUCT_PIVOT_DECISION.md
docs/current/go-backend-v2/28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
docs/current/go-backend-v2/29_FLAP_TARGET_ARCHITECTURE.md
docs/current/go-backend-v2/30_FLAP_F0_F11_EXECUTION_PLAN.md
docs/current/go-backend-v2/31_FLAP_LEGACY_RETIREMENT_MATRIX.md
docs/current/go-backend-v2/24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md
docs/current/go-backend-v2/README.md
docs/current/RULES_MASTER.md
.project-ai/context.md
.project-ai/glossary.md
.project-ai/rules/coding.md
.project-ai/rules/review.md
```

隔离 F0 worktree 已把执行计划安全命名为 `30_FLAP_F0_F11_EXECUTION_PLAN.md` 并同步当前链接；主脏工作区中的旧未跟踪文件不作为本提交证据，也不被删除。

## 5. 当前未关闭 Gate

```text
P1_03_REMEDIATION = FIX_READY / INDEPENDENT_RETEST_PENDING
P1_04_REMEDIATION = FIX_READY / INDEPENDENT_RETEST_PENDING
P2_02_REMEDIATION = FIX_READY / INDEPENDENT_RETEST_PENDING
P2_03_REMEDIATION = FIX_READY / INDEPENDENT_RETEST_PENDING
P2_04_REMEDIATION = FIX_READY / INDEPENDENT_RETEST_PENDING

P2_01_ISOLATED_COMMIT = OPEN
F0_DOCUMENT_FREEZE = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
TESTNET_DEPLOYMENT_ALLOWED = NO
BSC_MAINNET = NO-GO
```

本轮修订不把任何 Finding 自行标为 `CLOSED`。只有新独立 F0 Commit、完整可归因 Diff、Manifest/ZIP/companion Hash 齐全并通过下一轮独立审核后，才能进入 Owner Freeze。
