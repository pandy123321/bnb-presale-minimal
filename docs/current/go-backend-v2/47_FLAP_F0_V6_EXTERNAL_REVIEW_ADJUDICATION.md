# BingGoPlus Flap F0 V6 外部审核二次裁决

状态：`REMOTE_EVIDENCE_CLOSED / THREE_P1_ACCEPTED / V7_FIX_READY / P3_DETAIL_NOT_PROVIDED`

外部报告来源：责任人在当前任务中粘贴的 V6 审核结论与 Push 后远程 Evidence 复验结果。

```text
V6_PACKAGE_SHA256 = 79006bbbe4c0e9cae06996a60f05802cc6e7d197d2c7aee3701d8515b8d42c5b
V6_MANIFEST_SHA256 = ca9d8eb04de381559c2e4e73205a476b2f0a36f981bbba0b0226f92e889e1bad
V6_COMMIT = 46242c39f083684d7dc35dc403778e751c1ebf56
V6_PARENT = 849894ae3740fec21763954deb7c0a9af3c031c1
REMOTE_EVIDENCE_GATE = PASS
V6_CONTENT_REVIEW = CHANGES_REQUIRED
```

## 1. 远程 Evidence 裁决

外部复验确认 Branch Head 精确等于 V6 Commit，Baseline 到 Implementation 只有一个 Commit，Push 后无 drift，20 个变更文件与 Package 一致。因此此前因未 Push 导致的 `BLOCKED` 已关闭，不需要修改 V6 Commit 或重新包装相同内容。

## 2. Finding 裁决

### P1-F0V6-STAKING-01 — ACCEPTED

V6 只冻结 `early_exit_penalty_bps = 1000`，未冻结 penalty asset 的去向、principal liability 变化和是否可以转给外部地址。Legacy 权威实现与文档明确：完整 principal 被解除，用户只收净额；Penalty 与被没收未领取奖励回到同一 Staking Pool available Reward Reserve。

V7 修复要求：

```text
principal liability decrease = full principal
user return = principal - penalty
penalty external recipient = none
penalty + forfeited unclaimed reward = same Pool available Reward Reserve
no duplicate Tax Swap / Prefund accounting
```

### P1-F0V6-DIVIDEND-02 — ACCEPTED

V6 写了 `wallet_balance + active_staked_principal` 和系统地址排除，但没有精确定义 Staking/Vesting custody 的链上余额与 beneficial principal 的去重，也没有决定 Vesting 未释放量是否参与。相同 Token 可能在 custody address balance 与受益人 Position 两边重复计量。

V7 修复要求：所有 custody 地址排除；Staking principal 只按 staker Position 计一次；Vesting V1 未释放 Token 不参加 Dividend/Top100，释放到账后才从后续钱包快照参加；Snapshot 必须拒绝重复覆盖。

### P1-F0V6-ECON-03 — ACCEPTED

V6 五桶合计 10000，但未冻结 BGPlusVaultFactory 的 creation fee/revenue commission。若 Factory 仍从 Tax Revenue 抽成，就会产生隐藏第六出口并破坏五桶会计。

V7 修复要求：V1 creation fee = 0、revenue commission = 0、recipient = zero、Factory 不得接收 Vault outflow。外部 Flap/Gas 费用只能独立展示；若外部接口强制非零 commission，必须 Fail Closed 并重新进入 Owner Change Gate。

### P3 — UNABLE_TO_ADJUDICATE

责任人提供的摘要只包含 `P3 = 1`，没有 Finding ID、文件位置、证据或修复要求。执行方不得猜测或修改。该项不阻止先修三个 P1，但必须在 V7 独立复审中重新提供完整 Finding，才能关闭、接受延期或以反证拒绝。

## 3. 当前 Gate

```text
REMOTE_EVIDENCE_GATE = PASS
P1_F0V6_STAKING_01 = ACCEPTED / V7_FIX_READY
P1_F0V6_DIVIDEND_02 = ACCEPTED / V7_FIX_READY
P1_F0V6_ECON_03 = ACCEPTED / V7_FIX_READY
P3 = UNABLE_TO_ADJUDICATE / DETAIL_REQUIRED
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
BSC_MAINNET = NO-GO
```
