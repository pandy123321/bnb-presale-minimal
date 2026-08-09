# BingGoPlus — Global Rules (Distilled from 12 source documents)

> 以下 65 条规则整理自 `.project-ai/rules/`、`go-backend-v2/README.md`、`remediation/`、`24_AI_PROTOCOL.md`、`RT-GATE`、Phase/GE 提示词及 Flap F0 决策。每一条标注原始来源。Agent 违反任一规则 = 审核直接 BLOCKED。

---

## 一、执行边界（6 条）

| # | 规则 | 来源 |
|---|------|------|
| R1 | **一次一个阶段** — 同一执行轮次不得跨越未完成阶段。当前阶段完成后必须先完成独立审核、结论二次判定、证据记录与 Gate 登记；满足自动推进条件后，允许按当前已冻结阶段计划进入下一阶段 | Phase 提示词 / GE 闸门 / 24_AI_PROTOCOL.md |
| R2 | **一个阶段 = 一个独立 Commit** — 不可合并多阶段 | coding.md |
| R3 | **Commit 仅含阶段允许的文件** — S0 不有 Go，G1 不有 Solidity，RT-GATE 不有 Solidity | coding.md |
| R4 | **每阶段结束后 = 外部审核闸门** — APPROVED 才允许下一阶段。CHANGES_REQUIRED 修后重提，不可跳过 | 24_AI_PROTOCOL.md / GE 闸门 |
| R5 | **所有 P0/P1 关闭后才能推进** — P2 是否阻断以独立审核报告为准，不能由执行 Agent 自行豁免 | 24_AI_PROTOCOL.md |
| R6 | **BLOCKED 或 REJECTED → 停止全部开发** — 补齐材料或等待负责人重新授权 | 24_AI_PROTOCOL.md |

## 二、自动禁止（6 条）

| # | 规则 | 来源 |
|---|------|------|
| AUTOBAN-1 | **禁止审核前自动进入下一阶段** — 外部审核未 APPROVED、结论未完成二次判定或存在不确定/越界事项时必须停止；审核通过且自动推进条件全部满足时，允许按冻结计划自动进入下一阶段 | Phase/GE 提示词 / 24_AI_PROTOCOL.md |
| AUTOBAN-2 | **禁止自动 merge / push / deploy** — 所有阶段手动操作，CI 不可触发 | 旧 coding.md / manifest.yaml |
| AUTOBAN-3 | **禁止同轮跨阶段** — 一次 Agent session 不执行多个阶段 | 24_AI_PROTOCOL.md |
| AUTOBAN-4 | **禁止自动 OpenTrading** — CI、部署脚本、启动脚本、定时任务不可自动触发 | coding.md |
| AUTOBAN-5 | **禁止自行推断审核通过** — 等待真实外部 Verdict，不可编造或猜测 | 24_AI_PROTOCOL.md |
| AUTOBAN-6 | **禁止跨批自动执行** — GE / Phase 批次间必须审核 APPROVED 才能下一批 | GE-A01~A04 闸门 |

## 三、证据完整性（5 条）

| # | 规则 | 来源 |
|---|------|------|
| R7 | **完整 40 位 SHA** — 远程可解析。不用截断 SHA、main HEAD 或口头替代 | coding.md |
| R8 | **Diff 完整可读** — 不截断不 Binary。Evidence 文件 UTF-8 纯文本 | coding.md / RT-GATE |
| R9 | **Commit message 不是证据** — 声称"修了 P2-01"不等于内容验证。必须能逐行阅读最终正文 | coding.md |
| R10 | **Manifest Hash 与 payload 一致** — Manifest 外置，不 self-hash | coding.md / RT-GATE |
| R11 | **提审上下文完整** — PROJECT/STAGE/BASELINE/IMPLEM/Package SHA/Open Findings/SCOPE/NON_GOALS | 24_AI_PROTOCOL.md |

## 四、角色分离（3 条）

| # | 规则 | 来源 |
|---|------|------|
| R12 | **实现 Agent ≠ 独立批准** — 只能标 FIX_READY / INDEPENDENT_RETEST_PENDING，不可标 CLOSED/APPROVED/PASS | coding.md / remediation/README.md |
| R13 | **Design ≠ Review ≠ Adjudication Agent** — 必须不同 session/identity | coding.md / remediation/02_WORKFLOW.md |
| R14 | **仅修改 Allowed Paths** — 范围外问题只记录，不顺手扩展 | coding.md |

## 五、安全红线（7 条）

| # | 规则 | 来源 |
|---|------|------|
| R15 | **Mainnet NO-GO** — chain 56 配置和数据库双重禁止。所有脚本在 chain 56 上必须 revert | Go V2 README / coding.md |
| R16 | **OpenTrading 不可自动** — 不可被 CI/脚本/定时任务触发。必须人工单独一次性授权 | coding.md |
| R17 | **合约不可以"已修复"名义重部署** — 源码修改是候选，不可标"链上已生效" | Go V2 README |
| R18 | **经济参数按产品版本和生命周期冻结** — 已部署 PANGU2 参数不可改；Flap 新 Token 仅能设置参数目录允许值，链上确认后按 `LAUNCH_IMMUTABLE / GOVERNANCE_ADJUSTABLE / OPERATION_INPUT` 管理，不得越权改写 | 00_FINDINGS.md / Flap F0 文档 27-31 |
| R19 | **私钥/Secret 不外泄** — 不入代码、日志、Commit、文档、测试、Evidence | coding.md |
| R20 | **不可伪造测试** — 未运行写 NOT_RUN。TEST EXPECTED != RUNTIME 时不可改 Expected 后标 PASS | coding.md / RT-GATE |
| R21 | **不可吞错误** — 不用 || true / continue-on-error / 空 catch | coding.md |

## 六、审核结论唯一允许值（6 条）

| # | 规则 | 来源 |
|---|------|------|
| R22 | **Verdict 只能三个值** — APPROVED / CHANGES_REQUIRED / BLOCKED。严禁 CONDITIONAL YES/建议合并/基本通过 | remediation/02_WORKFLOW.md |
| R23 | **APPROVED_CODE_ONLY != 可部署** — 仅代码层通过。不授权 Bootstrap/Finalize/OpenTrading/部署/G1/Mainnet | remediation/README.md |
| R24 | **CHANGES_REQUIRED != 审核意见全部正确** — 只有 CONFIRMED 的 Finding 才进入修复 | remediation/README.md |
| R25 | **Verdict 必须注明下一阶段授权** — S1_ALLOWED = YES/NO | remediation/README.md |
| R26 | **P0/P1 不可"后续再处理"关闭** — P2 由负责人判定。P3 只有用户书面签署 ACCEPTED_DEVIATION | remediation/README.md |
| R27 | **"先通过以后再查" = 严禁** — 未验证项不 PASS | coding.md / RT-GATE |

## 七、审核工作流（6 条）

| # | 规则 | 来源 |
|---|------|------|
| R28 | **强制闭环**: Pre-Fix Review -> Adjudication -> 仅 CONFIRMED -> 实现 -> 本地验证 -> Commit -> Post-Fix Review -> Adjudication -> 仅 CONFIRMED -> Fix -> Re-Review -> APPROVED_CODE_ONLY -> Closeout | remediation/README.md |
| R29 | **Pre-Fix Review 必须在改代码前** — 确认 Finding 存在/严重性正确/修复边界足以关闭攻击路径且不违反经济基线。只有审核+校对均确认后才允许实现 | remediation/02_WORKFLOW.md |
| R30 | **阶段独立审核必须阅读** — 全部已修改合约 + 接口 + 库 + 直接交互合约 + 新增/修改测试源代码 + 真实执行证据 | remediation/02_WORKFLOW.md |
| R31 | **审核 Finding 格式完整** — ID/Severity/Status/File/Line/Commit 证据/Attack Preconditions/Attack Path/Impact/Root Cause/Required Fix/Regression Risk/Required Verification | remediation/02_WORKFLOW.md |
| R32 | **无 Finding 也必须列出** — Verified Non-Issues/测试边界/未执行项/剩余风险。不可只写"没有发现" | remediation/02_WORKFLOW.md |
| R33 | **校对 Agent 逐条判定**（只能以下五值之一）: CONFIRMED / REJECTED_WITH_EVIDENCE / DUPLICATE / NEEDS_MORE_EVIDENCE / SCOPE_EXPANSION_REQUIRED。NEEDS_MORE_EVIDENCE 或 SCOPE_EXPANSION_REQUIRED -> 停止并请求用户 | remediation/02_WORKFLOW.md |

## 八、大阶段全量审核（3 条）

| # | 规则 | 来源 |
|---|------|------|
| R34 | **合约全量审核必须读完整合约范围**（不仅是 diff）。PANGU2 阶段读取 `contracts-v2/src/**`；Flap 新合约阶段读取 `contracts-flap/src/**`、接口、库和直接交互合约。复核接口/状态/权限/资金流、绕过、重入、错误税率、会计漂移、角色接管和永久 DoS | remediation/README.md / Flap F0 |
| R35 | **大审核 != 已部署** — 判断 CODE_DEPLOYABILITY = YES/NO，不可声明实际部署通过 | remediation/README.md |
| R36 | **大审核不可由本大阶段实现 Agent 签发** — Priority Full Audit Agent 必须是独立 session | remediation/02_WORKFLOW.md |

## 九、跨文件一致性（4 条）

| # | 规则 | 来源 |
|---|------|------|
| C1 | Markdown 与机器规范必须同 revision（提审包同一 Commit）。缺 SQL/OpenAPI/Event/State 时受影响项标 BLOCKED/UNABLE_TO_VERIFY | review.md |
| C2 | Decision / Invariant / Compliance / Stage Evidence 中同一决策的状态必须完全相同。一个文档 PENDING 另一个 FROZEN -> P2 | review.md |
| C3 | 00 status / 02 Matrix / 测试脚本 SP evidence / Evidence 输出中计数必须一致。不一致 -> P2 | review.md / RT-GATE |
| C4 | Manifest Hash / Evidence Hash / Matrix 引用的 Hash 必须匹配实际文件内容。不匹配 -> Evidence Integrity FAIL | RT-GATE |

## 十、SP Evidence 规则（3 条）

| # | 规则 | 来源 |
|---|------|------|
| SP-1 | **SP 测试必须 assertion-style（fail-safe）** — 负向测试 unexpected success -> RAISE EXCEPTION；错误 SQLSTATE -> RAISE EXCEPTION。正向测试操作失败 -> RAISE EXCEPTION。严禁 WHEN OTHERS => RAISE NOTICE 'PASS'（fail-open） | RT-GATE |
| SP-2 | **SP evidence 格式为 machine-readable pipe-delimited** — TEST_ID|ROLE|EXPECTED|SQLSTATE|ACTUAL|ERROR | RT-GATE |
| SP-3 | **TEST EXPECTED != RUNTIME TRIGGER != 改 Expected 后标 PASS** — 差异 -> 报告冲突，不修改冻结验收条件 | RT-GATE |

## 十一、Laravel 遗留（2 条）

| # | 规则 | 来源 |
|---|------|------|
| L-1 | **Laravel 已废弃** — 不修 Bug、不补齐功能、不新增路由/Controller。所有后端能力由 Go V2 接管 | 用户决策 |
| L-2 | **旧 Worker 不可与 Go Worker 写同一 Database/Schema** — 旧 Mock/Session/队列状态不迁移 | Go V2 README |

## 十二、Go V2 开发（2 条）

| # | 规则 | 来源 |
|---|------|------|
| G-1 | **backend-go/ 不存在时不可声称 Build 通过。Go 依赖当前 NO_DOWNLOAD_AUTHORIZED。不可用 latest/浮动 branch/未批准 pseudo-version** | Go V2 README / RT-GATE-03 |
| G-2 | **G1 仅允许 skeleton** — cmd/config/health/DB bootstrap。严禁任何业务逻辑 | coding.md |

## 十三、Flap 产品主线（12 条）

| # | 规则 | 来源 |
|---|---|---|
| F-1 | **新 Token 必须通过 Flap 发币** — 只允许已固定 Chain ID、地址、ABI 和 runtime hash 的 Portal/VaultPortal；普通 Factory 或 PANGU2 脚本不得冒充 Flap Launch | 27_FLAP_PRODUCT_PIVOT_DECISION.md |
| F-2 | **PANGU2 只读遗产** — 已部署合约、历史和 Evidence 保留且不可重部署；CostBasis、动态盈利税、专用 Router/Settlement、Whitelist、Top100 35/25/25/15 四档和 PANGU2 专用 Staking 实现不得进入新产品；开盘保护、Top100 奖励与 Staking 业务目的只能按 Flap 兼容模型重做 | 27/31 Flap F0 |
| F-3 | **Flap 参数必须来自目录和生命周期** — 创建前可编辑；链上不可变项确认后只读；治理可调项需 Command/审批/事件；禁止任意 target/selector/calldata | 28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md |
| F-4 | **经济结构尽量继承但语义不得伪造** — 保留资金桶、回购锁仓、Merkle、质押偿付和安全控制；单一 Flap Tax 不得宣传成 PANGU2 买卖/盈利税 | 27/28/31 Flap F0 |
| F-5 | **Guardian 最小权限** — 可触发固定规则动作，不得改 BPS、收款地址、管理员、Root 或任意提款；新 Factory/Vault 必须独立 Solidity Gate | 27/29 Flap F0 / 合约安全规范 V1.0 |
| F-6 | **当前阶段为 Flap F0-F11** — 旧 G2-G9 对当前执行已被取代；F10 只做通用 Staking，F11 单独做 Legacy Cutover；每阶段独立 Commit/Manifest/审核/裁决，F0/F2、Signer、Migration、测试网链写和新 Solidity 部署保持人工 Gate | 30_FLAP_F0_F11_EXECUTION_PLAN.md |
| F-7 | **独立审核统一由用户手动提交** — 执行 Agent 只生成完整提审包、Manifest、Hash 和提示词，不寻找、不调用、不轮询外部审核工具；用户回传完整报告后再进行二次裁决 | 24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md / 用户明确决策 |
| F-8 | **F6 不得自动进入 F7** — F6 Native MVP 审核通过后必须暂停；F7 虽是必做路线，但首次进入自建金融 Solidity 和 RevenueVault 资金域，必须通过 Extension Entry Review 与 Responsible Owner/Security Scope Authorization 后显式设置 `F7_ENTRY_AUTHORIZED=YES` | 24/30 Flap F0 |
| F-9 | **V6 默认经济模型必须唯一** — Token Tax 候选默认 500 BPS；Revenue 五桶默认 Dividend/Buyback-Burn/Staking/Marketing/Operations = 3000/2500/2000/1500/1000，Launch 前可调、总和必须 10000、确认后冻结 | 28 Flap F0 / Owner V6 Decision |
| F-10 | **Top100 是额外池而非旧四档** — 所有有效持有人领取基础分红；Top100 由固定快照、有效余额降序和地址升序确定，并按榜内有效余额同比例分配额外池；禁止恢复 35/25/25/15 | 28/31 Flap F0 / Owner V6 Decision |
| F-11 | **Staking 税收奖励与本金隔离** — 只有 Staking Bucket 可在 MIGRATED/ACTIVE 后受控兑换绑定 Token；可外部预充值；其他 Bucket 和质押本金永远不得支付奖励 | 28/29/30 Flap F0 / Owner V6 Decision |
| F-12 | **开盘保护和 Vesting 必须 Fail Closed** — 旧保护真实基线是 15 分钟/30% 税而非 15% 税；只在 F1/独立 Solidity Gate 证明兼容时启用，保护税替代普通税且仍走五桶，不得叠加或恢复 29%+1% 旧路径。Vesting 仅锁定真实预充值 Token，不铸币、不复用回购 Locker | 27/28/31 Flap F0 / Owner V6 Decision |

---

## 来源文件索引

1. .project-ai/rules/coding.md
2. .project-ai/rules/review.md
3. docs/current/go-backend-v2/README.md
4. docs/current/go-backend-v2/24_AI_CODE_REVIEW_AUTOMATION_PROTOCOL.md
5. docs/current/go-backend-v2/runtime-gate/00_RUNTIME_GATE_STATUS.md
6. docs/current/go-backend-v2/contracts/remediation/README.md
7. docs/current/go-backend-v2/contracts/remediation/00_AUDIT_FINDINGS_BASELINE.md
8. docs/current/go-backend-v2/contracts/remediation/02_REVIEW_WORKFLOW_AND_PROMPTS.md
9. docs/current/go-backend-v2/contracts/BSC_TESTNET_DEPLOYMENT_BASELINE.md
10. docs/current/go-backend-v2/05_BUSINESS_AND_CONTRACT_INHERITANCE.md
11. Phase 0-9 / GE-A01~A04 分批提示词
12. 用户明确决策
13. docs/current/go-backend-v2/27_FLAP_PRODUCT_PIVOT_DECISION.md
14. docs/current/go-backend-v2/28_FLAP_PRODUCT_SCOPE_AND_PARAMETER_CATALOG.md
15. docs/current/go-backend-v2/29_FLAP_TARGET_ARCHITECTURE.md
16. docs/current/go-backend-v2/30_FLAP_F0_F11_EXECUTION_PLAN.md
17. docs/current/go-backend-v2/31_FLAP_LEGACY_RETIREMENT_MATRIX.md

## 规则冲突消解与自动推进补充（高于同主题旧表述）

1. “一次一个阶段”表示同一执行轮次不得跨越未完成的阶段；当前阶段通过独立审核、完成结论二次判定且满足自动推进条件后，可以按当前已冻结计划开始下一阶段。
2. 自动推进条件：`EXTERNAL_REVIEW_VERDICT = APPROVED`、`EXTERNAL_REVIEW_ADJUDICATION = ACCEPTED`、`REVIEW_COMPLETENESS = COMPLETE`、无未判断阻断项、无范围外任务、验收通过、下一阶段已定义、Package/Commit Hash 匹配。
3. 审核未通过、结论无法判断、证据不足、范围越界、包或 Commit 不匹配、下一阶段未定义时，必须暂停，不得推进。
4. 原始审核 Verdict 仅使用 `APPROVED / CHANGES_REQUIRED / BLOCKED`；`APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE` 和 `APPROVED_FOR_NEXT_STAGE` 是阶段授权状态，不代表部署、主网或合约操作批准。
5. 一个阶段原则上对应一个实现 Commit；仅包含上下文、审核记录或状态同步且不含实现变更的记录 Commit，不视为跨阶段实现。
6. 审核报告必须提供文件路径、行号/函数或对象、证据、根因、影响、具体修复步骤、约束、验收标准和回归检查。只报问题而不给可执行修复方案时，`REVIEW_COMPLETENESS = INCOMPLETE`，不得推进。
7. 本文件当前分组数量合计为 65 条；后续新增或删除规则必须同步更新总数。
