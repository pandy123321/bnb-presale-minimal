# BingGoPlus Flap F0 V7 P1 修订作者侧自审

状态：`AUTHOR_SELF_REVIEW / THREE_P1_FIX_READY / INDEPENDENT_RETEST_PENDING`

## 1. 范围

本轮只修复 V6 外审确认的三个内容 P1，并同步 Current Authority、规则、阶段和审核提示词。没有修改 Go、SQL、OpenAPI、Event/State、前端业务代码、Solidity、部署地址或链上状态。

## 2. 修订矩阵

| Finding | 作者侧状态 | V7 修订 |
|---|---|---|
| `P1-F0V6-STAKING-01` | `FIX_READY` | EarlyUnstake 完整 principal liability 减少；净额返用户；罚金与 forfeited reward 回同 Pool Reward Reserve；无外部 Recipient/重复入账 |
| `P1-F0V6-DIVIDEND-02` | `FIX_READY` | custody 地址全部排除；Staking principal 按 staker 一次计量；Vesting 未释放量不参加；Snapshot 拒绝重复覆盖 |
| `P1-F0V6-ECON-03` | `FIX_READY` | Factory V1 creation fee/commission 固定为 0，不能接收 Vault outflow；外部 Flap/Gas fee 独立 |
| 未提供详情的 P3 | `NOT_EXECUTED` | `UNABLE_TO_ADJUDICATE / DETAIL_REQUIRED`，不猜测修复 |

## 3. 不变量

```text
PENALTY_RECIPIENT = SAME_STAKING_POOL_REWARD_RESERVE
PENALTY_EXTERNAL_TRANSFER = NO
PRINCIPAL_DOUBLE_COUNT = FORBIDDEN
CUSTODY_DIRECT_DIVIDEND = FORBIDDEN
STAKING_PRINCIPAL_ATTRIBUTION = EXACTLY_ONCE_TO_STAKER
VESTING_UNRELEASED_DIVIDEND = NO
FACTORY_CREATION_FEE_WEI = 0
FACTORY_REVENUE_COMMISSION_BPS = 0
FACTORY_VAULT_OUTFLOW = FORBIDDEN
```

## 4. Gate

```text
V7_P1_REMEDIATION = FIX_READY
INDEPENDENT_RETEST = PENDING
SELF_APPROVAL = FORBIDDEN
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
TESTNET_DEPLOYMENT_ALLOWED = NO
BSC_MAINNET = NO-GO
```

## 5. 未执行

静态检查：

```text
AUTHORITATIVE_FILES = 56
MISSING_FILES = 0
MARKDOWN_FILES = 50
RELATIVE_LINKS = 113
MISSING_LINKS = 0
UNBALANCED_FENCES = 0
RULE_SECTION_SUM = 68
CONTEXT_VERSION = 23
CHANGED_FILES = 21
OUT_OF_SCOPE_CODE_FILES = 0
```

运行时和实现检查未执行：

```text
Go/Frontend/Solidity build or test
Migration/PostgreSQL/Docker
RPC/Fork/Flap Portal call
Signature/Broadcast/Deployment
Dependency download
Push/Merge
```
