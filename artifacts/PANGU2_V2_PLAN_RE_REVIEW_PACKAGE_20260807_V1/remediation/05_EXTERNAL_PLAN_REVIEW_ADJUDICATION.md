# 外部方案审核结论校对记录

```text
Review Input: cloud plan review pasted-text.txt
Review Verdict Received: CHANGES_REQUIRED
Adjudication Verdict: REVIEW_VERDICT_CONFIRMED = YES
Fix Allowed: YES, documentation plan only
Solidity Changes: NONE
Solidity Implementation Allowed: NO
S0 Gate Approval: NOT_GRANTED; RE-REVIEW_REQUIRED
Deployment Approval: NOT_GRANTED
Mainnet: NO-GO
```

## 1. 总体判断

云端报告的总体 `CHANGES_REQUIRED` 正确：mandatory Build Gate、Staking typed position context、资金恒等式、舍入规则、Preview revision 语义和合约账户生命周期需要在 S0 批准前补强。

报告没有收到 README、00/01/02/03 和权威基线，因此它拒绝签发 S0 Gate 也是正确的证据边界。但这是“上传包不完整”，不是这些文件在本地不存在。本轮增加独立提交清单，防止复审再次遗漏。

云端使用的 GitHub public main 与本地目标 Commit 不同。涉及 whitelist 和 Oracle 当前实现的结论必须以本地 `3ef50b6/Review HEAD` 为准，不能直接继承云端辅助快照。

## 2. Finding 校对

| 外部结论 | 校对分类 | 本地证据/判断 | 已执行修改 |
|---|---|---|---|
| PLAN-P1-01 Build 可 NOT_RUN 仍推进 | CONFIRMED | 原 S1 确实允许 `BUILD=PASS or NOT_RUN_WITH_BLOCKER` | S1–S8B 改为 mandatory Build；失败/未运行不得推进 |
| PLAN-P1-02 Staking mutation path 不唯一 | CONFIRMED | 当前 `systemTransfer(to,amount,kind)` 不携带 positionId；原计划未完全禁止双写 | S0/S3 冻结 typed context 和 onlyToken 单一路径 |
| PLAN-P1-03 Staking 资金状态不完整 | CONFIRMED | 原计划没有完整冻结 normal exit reward、penalty、no-staker liability、dust | S0/S4A 增加完整状态和恒等式 |
| PLAN-P1-04 S8 lifecycle 不足 | CONFIRMED | 原 S8 只有原则，没有可编码的 revoke/exit 状态机 | 新 S8A 使用 NONE→APPROVED→EXIT_ONLY→REVOKED；S8B 隔离防绕过 |
| PLAN-P2-01 proportional floor/split tax | CONFIRMED | 原规则没有防止 4%/10% 分类受取整影响的精确定义 | S0 增加精确有理数利润比较、carry/remainder 和 canonical split 性质 |
| PLAN-P2-02 CostBasis 等式范围 | CONFIRMED | 原 `actual=known+unknown` 未限定 eligible liquid users | S0 明确排除 Pair/System/协议托管和 staked lots |
| PLAN-P2-03 revision 语义不明确 | CONFIRMED | 原 S2 同时写 revision/quote block，未定义是 diagnostic 还是 lock | S0 强制二选一；S2 必须按冻结语义实现 |
| PLAN-P2-04A canonical whitelist source 未写入计划 | CONFIRMED | 计划此前没有列出 storage/admin/trading/launch 单一来源 | S0/S2 增加 canonical source mapping 和目标 SHA 复核 |
| PLAN-P2-04B 本地目标源码可能没有 whitelist/launch | REJECTED_WITH_EVIDENCE | 本地 `Pangu2Token` 明确包含 `feeWhitelist`、`tradingOpenAt`、`resolveBuyTaxBps`、`resolveSellTaxBps` | 不删除 Finding；只要求执行时核对目标 SHA |
| S4 应拆 Reward 与 Pause | CONFIRMED | 原 S4 同时改奖励状态机和角色/暂停，风险面过大 | 拆为 S4A、S4B；M2 在 S4B 后 |
| S8 FIX 应拆 lifecycle 与 bypass regression | CONFIRMED | Registry 生命周期和 Pair/Router 攻击面不同 | 拆为 S8A、S8B；M3 在 S8B 后 |
| deployment scripts 绝对禁止修改会阻断 Build | CONFIRMED_WITH_SCOPE_CONTROL | Foundry `script="script"`；constructor/interface 变化可能破坏完整编译 | 新增需用户批准的 `COMPILE_COMPATIBILITY_EXCEPTION`；仍禁止部署逻辑/执行 |
| S5 优先复用 Adapter canonical quote | CONFIRMED | 本地 Adapter 已有固定 Token/WBNB `quoteExactInput` | S5 明确优先复用，不开放任意 pair/path |
| current Oracle 已部分/完全处理 uint32 rollover | REJECTED_FOR_TARGET_SNAPSHOT | 本地目标代码仍有 `if (ts > uint32(block.timestamp)) revert PairTimestampAhead(ts)` | 保留 S7，并增加 long-gap/re-anchor 规则 |
| 缺少 README/00/01/02/03 | CONFIRMED_AS_SUBMISSION_GAP | 文件本地存在，但云端未收到 | 新增完整上传清单和 hash manifest 要求 |

## 3. 阶段结构变更

修订后顺序：

```text
S0
→ S1 → S2 → M1
→ S3 → S4A → S4B → M2
→ S5 → S6 → S7
→ S8A → S8B → M3
→ S9 / FINAL
```

S1–S8B 每阶段必须：

```text
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
```

Unit/Fuzz/Invariant 可以因工具不可用标记 NOT_RUN，但 Build 不能在未通过时推进。

## 4. 仍未授予的权限

本轮只是修复计划文档，不是 S0 设计成果本身。下一步必须把完整修订包重新提交独立方案审核。

```text
PLAN_REMEDIATION_STATUS = READY_FOR_EXTERNAL_RE_REVIEW
S0_GATE_APPROVAL = NOT_GRANTED
SOLIDITY_IMPLEMENTATION_ALLOWED = NO
DEPLOYMENT_APPROVAL = NOT_GRANTED
BSC_TESTNET_RUNTIME_FIXED = NO
MAINNET = NO-GO
```

