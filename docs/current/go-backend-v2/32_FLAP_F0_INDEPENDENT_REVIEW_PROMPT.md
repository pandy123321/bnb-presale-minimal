# BingGoPlus Flap F0 独立审核提示词

你是 BingGoPlus Flap 产品转向 F0 独立审核 Agent。只读审核，不得修改任何文件，不得运行 Go/前端/Solidity 测试、构建、数据库 Migration、RPC、Fork、签名、广播或部署。

## 一、审核目标

判断本次从 PANGU2 主线转向 Flap 的文档冻结候选是否完整、一致、可实现，并且没有把已永久放弃的 PANGU2 专用逻辑通过后端或新 Vault 偷偷恢复。

标准 Verdict 只能是：

```text
APPROVED
CHANGES_REQUIRED
BLOCKED
```

本轮只能批准进入 Responsible Owner Freeze/F1 Baseline，不批准代码实现、依赖下载、测试网签名、部署或 Mainnet。

## 二、必须读取

```text
docs/current/go-backend-v2/27_FLAP_PRODUCT_PIVOT_DECISION.md
docs/current/go-backend-v2/28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
docs/current/go-backend-v2/29_FLAP_TARGET_ARCHITECTURE.md
docs/current/go-backend-v2/30_FLAP_F0_F11_EXECUTION_PLAN.md
docs/current/go-backend-v2/31_FLAP_LEGACY_RETIREMENT_MATRIX.md
docs/current/go-backend-v2/32_FLAP_F0_INDEPENDENT_REVIEW_PROMPT.md
docs/current/go-backend-v2/33_FLAP_F0_SELF_REVIEW.md
docs/current/go-backend-v2/34_FLAP_F0_SUBMISSION_CONTEXT.md
docs/current/go-backend-v2/35_FLAP_F0_V2_EXTERNAL_REVIEW_ADJUDICATION.md
docs/current/go-backend-v2/36_FLAP_F0_V3_REMEDIATION_SELF_REVIEW.md
docs/current/go-backend-v2/37_FLAP_F0_V3_SUBMISSION_CONTEXT.md
docs/current/go-backend-v2/38_FLAP_F0_V3_EXTERNAL_REVIEW_ADJUDICATION.md
docs/current/go-backend-v2/39_FLAP_F0_V4_REMEDIATION_SELF_REVIEW.md
docs/current/go-backend-v2/40_FLAP_F0_V4_SUBMISSION_CONTEXT.md
docs/current/go-backend-v2/41_FLAP_F0_V4_EXTERNAL_REVIEW_ADJUDICATION.md
docs/current/go-backend-v2/42_FLAP_F0_V5_REMEDIATION_SELF_REVIEW.md
docs/current/go-backend-v2/43_FLAP_F0_V5_SUBMISSION_CONTEXT.md

docs/current/go-backend-v2/25_FLAP_INTEGRATION_EXECUTION_PLAN.md
docs/current/go-backend-v2/26_G2_EXECUTION_BASELINE_NORMALIZATION.md
docs/current/go-backend-v2/README.md
docs/current/RULES_MASTER.md
docs/current/ECONOMIC_MODEL.md
docs/current/PRODUCT_PLANNING.md
docs/current/go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md
docs/current/go-backend-v2/24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md
.project-ai/context.md
.project-ai/architecture.md
.project-ai/glossary.md
.project-ai/rules/coding.md
.project-ai/rules/review.md

开源项目通用引用准入规则V1.0.md
通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md
```

同时读取权威 `PAYLOAD_MANIFEST.csv`、外层 Package SHA-256、固定 Commit 和完整 Diff。任何缺失、Hash 不一致或文件不可读均按 Evidence 规则处理。

## 三、必须验证

### A. 主线和历史边界

1. `PRODUCT_MAINLINE = FLAP` 是否跨文件一致；
2. 旧 G2-G9 是否只标记 `SUPERSEDED`，没有伪造历史；
3. PANGU2 合约、地址、测试网历史和 Evidence 是否保留；
4. 是否禁止重部署现有 PANGU2；
5. Mainnet 是否保持 NO-GO。

### B. Flap 真实性

6. 是否明确 Portal/VaultPortal 是发币入口；
7. 是否禁止旧 `Factory.createToken()` 假设；
8. 是否要求 F1 固定地址、ABI、selector、runtime bytecode hash 和默认值；
9. 是否把 Flap API 限制为非权威辅助，链上 receipt/event 为事实；
10. 是否要求索引 `TokenCreated` 和同交易补充事件。

### C. 经济继承和永久退役

11. 是否保留 Bucket、回购、锁仓、Merkle、质押储备与安全控制结构；
12. 参数是否明确区分生命周期和边界；
13. CostBasis、动态盈利税、PANGU2 Router/settlement、Launch Tax、Whitelist 是否永久退役；
14. Top100 35/25/25/15 是否没有通过新名称恢复；
15. 新 Dividend 是否明确为所有符合条件地址同比例；
16. Flap Curve 和 DEX 阶段税费是否分别展示，是否禁止“始终 4%”误导；
17. 参数默认值是否被误写成已部署事实或全局不可变值。

### D. 合约和资金安全

18. 自建 Factory/Vault/Buyback/Locker/Dividend/Staking 是否都要求独立 Solidity Gate；
19. Guardian 是否只能触发固定规则动作，不能改配置或提款；
20. 回购是否只能买绑定 Token，所得只能锁仓或 burn；
21. Curve 阶段是否默认不执行自建回购；
22. Vault 会计、分红、锁仓和质押不变量是否完整；
23. 是否禁止单 EOA 长期控制全部资金；
24. 是否禁止任意 target/selector/calldata。

### E. 架构、数据库和 API

25. 新多 Launch Schema 是否与旧单 Deployment Set 隔离；
26. 新表名是否仍标为 F2 候选，没有提前伪造 Machine Freeze；
27. Launch API 是否是异步工作流；
28. Approved parameter snapshot、request hash、idempotency、receipt、finality、Reorg 是否闭合；
29. Admin Wallet 和 Platform Signer 是否分开；
30. 旧 PANGU2 API/页面是否有安全退役路径。

### F. 阶段和审核规则

31. F0-F11 是否一阶段一 Commit/Package/Review，且 F10 Staking 与 F11 Legacy Cutover 是否严格分离；
32. F0/F2、Solidity、部署、Signer、Migration 是否保留人工 Gate；
33. 用户手动取得的独立审核结果是否要求执行方二次裁决；
34. 错误 Finding 是否明确不执行并记录 Counter-Evidence；
35. 审核 Finding 是否必须给出具体修改方法而非只报问题。

### G. V2 外部报告二次裁决

36. 是否正确保留责任人已明确的“当前项目原地转 Flap”方向，而没有被外部报告擅自改成独立新项目；
37. 是否正确保留后台 `ADMIN_WALLET` 一键发币，并在 F1 增加 creator/payer/msg.sender/initial buyer 精确核对；
38. Legacy RT02/RT03 是否不再被 `.project-ai` 或 README 错写为全部 PASS；
39. RevenueVault 五个 Bucket 是否都有目的地、授权动作、触发者、冻结时点、流出类型和会计守恒；
40. Split Vault 等能力是否区分官方文档事实与 F1 runtime baseline；
41. F10 Staking 与 F11 Legacy Cutover 是否是独立 Commit、审核包、部署和回滚单元；
42. 手动审核没有任务号时是否使用 `N/A_USER_MANUAL`，并记录 Artifact ID、报告 Hash、时间和 Reviewer Identity；
43. V2 被拒绝执行的错误 Finding 是否有责任人原始输入反证，且没有被偷偷执行。

### H. V3 外审修订复验

44. F3～F6 是否唯一映射为 Chain/Indexer/Read Model、Workflow/API、Signer/Execution、Admin Console/Native MVP；
45. F6 审核通过时是否仍强制 `AUTO_ADVANCE_DECISION=PAUSED`，直到 F7 Extension Entry Review 和 Owner/Security Scope Authorization；
46. F7～F10 是否仍为必做路线，没有因暂停 Gate 被降为 Optional；
47. Staking 是否唯一使用绑定 Flap Token 的 `EXTERNAL_PREFUND_ONLY`，不使用 RevenueVault BNB 或质押本金；
48. `/api/v2`、`binggoplus_v2`、旧 G5/G6 是否只出现在明确 `LEGACY/HISTORICAL` 语义；
49. Flap 三模式是否仍标记为 Candidate/Pending F1，而不是已实现“支持”；
50. RevenueVault 是否冻结 Internal Ledger 事实源、链余额仅作 Solvency、未登记 Surplus 不可分配；
51. Outflow 是否有唯一 execution identity、成功不可重复、失败重试复用原 identity。

### I. V4 外审修订复验

52. doc27/doc30/doc31 是否不再把当前 Gate 绑定到 V2、doc37 或旧 Commit；
53. 当前 Commit 是否通过 doc43 与 Package `COMMIT_ID.txt` 精确绑定，并与完整 Diff/Name Status 一致；
54. `APPROVED` 是否只表示当前审核范围通过，Flap F0 是否只能进入 Responsible Owner Freeze；
55. 是否只有 `ADJUDICATION=ACCEPTED + OWNER_FREEZE=SIGNED` 才能把 `F1_ENTRY_AUTHORIZED` 改为 YES；
56. doc28 高层是否使用“计划支持/Pending F1/Solidity Gate”，没有残留已验证“支持”语义；
57. RULES_MASTER、coding.md 和机器计数是否全部为 61。

## 四、Finding 输出要求

每条 Finding 必须包含：

```text
ID
Severity = P0/P1/P2/P3
Status
File + line/function/object
Evidence
Root Cause
Impact
Required Fix（具体改什么、改到哪里、如何改）
Constraints
Acceptance Criteria
Regression Checks
```

只指出问题但不给可执行修复方案时：

```text
REVIEW_COMPLETENESS = INCOMPLETE
NEXT_STAGE_AUTHORIZATION = NO
```

## 五、最终输出

```text
VERDICT = APPROVED / CHANGES_REQUIRED / BLOCKED
REVIEW_COMPLETENESS = COMPLETE / INCOMPLETE
F0_DOCUMENT_FREEZE = APPROVED_FOR_OWNER_SIGNOFF / NO
F1_ENTRY_ALLOWED = YES / NO
FLAP_IMPLEMENTATION_ALLOWED = NO
TESTNET_DEPLOYMENT_ALLOWED = NO
BSC_MAINNET = NO-GO
```

必须列出 Verified Non-Issues、未执行项、剩余风险和所审 Commit/Package SHA-256。不得把文档审核通过描述为代码、测试或部署通过。
