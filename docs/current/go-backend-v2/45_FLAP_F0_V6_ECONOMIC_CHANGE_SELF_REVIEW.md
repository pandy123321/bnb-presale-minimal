# BingGoPlus Flap F0 V6 经济模型变更作者侧自审

状态：`HISTORICAL_V6_AUTHOR_SELF_REVIEW / EXTERNAL_REVIEW_CHANGES_REQUIRED / SUPERSEDED_BY_V7_REMEDIATION`

> 本文保留 V6 提审前作者侧记录。V6 外部内容审核发现 3 个 P1；当前裁决见文档 47，当前修订自审见文档 48。

## 1. 范围

本轮只处理 Owner 新经济模型与“尽量保留旧机制”的文档基线。没有修改 Go、SQL、OpenAPI、Event/State、前端业务代码、Solidity、部署地址或链上状态。

## 2. 经济模型自检矩阵

| 项目 | V6 结果 |
|---|---|
| Token Tax | 候选默认 500 BPS；F1 支持范围待证；Launch 前可调、确认后冻结 |
| Revenue Buckets | 3000/2500/2000/1500/1000，合计 10000 |
| Dividend | 所有有效持有人基础池 + Top100 额外池 |
| Top100 | 有效余额降序、地址升序打破同额；榜内按有效余额同比例；不恢复四档 |
| Buyback | 仅 MIGRATED/ACTIVE；默认 100% Burn；可在 Launch 前配置 Locker 比例 |
| Staking | Staking BNB Bucket 受控兑换 + 可选外部预充值；principal 永不支付奖励 |
| Vesting | 独立预充值、不铸币、不复用回购 Locker；F1 验证 Token 分配/转账语义 |
| Launch Protection | 旧真实基线 15 分钟/30% 税；不是 15% 税；启用时替代普通 5% 且仍走五桶；待 F1/独立 Solidity Gate |
| Accounting | Internal Revenue Ledger 是唯一分配事实源；实际余额仅作 solvency；outflow identity 防重 |

## 3. 保留与退役边界

已保留业务目的/安全不变量：开盘保护、税收用途隔离、回购额度/间隔、销毁/锁仓去向、Merkle、一人一次领取、carry、Top100 奖励、Staking 锁期/罚金/本金隔离、团队/投资人/项目 Vesting、最小权限和 Fail Closed。

未恢复：CostBasis、盈利动态税、PANGU2 Router/settlement、Whitelist、Top100 35/25/25/15 四档、现有 PANGU2 重部署。

## 4. Gate 自检

```text
V5_CONTENT_APPROVAL = HISTORICAL / SUPERSEDED_FOR_FREEZE
F0_DOCUMENT_FREEZE = NO
V6_INDEPENDENT_REVIEW = PENDING
F0_OWNER_FREEZE_ALLOWED = NO
F1_ENTRY_AUTHORIZED = NO
FLAP_IMPLEMENTATION_ALLOWED = NO
TESTNET_DEPLOYMENT_ALLOWED = NO
BSC_MAINNET = NO-GO
```

## 5. 未执行

静态检查：

```text
AUTHORITATIVE_FILES = 53
MISSING_FILES = 0
MARKDOWN_FILES = 47
RELATIVE_LINKS = 106
MISSING_LINKS = 0
UNBALANCED_FENCES = 0
RULE_SECTION_SUM = 65
CONTEXT_VERSION = 22
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

## 6. 作者侧结论

```text
V6_ECONOMIC_MODEL_CHANGE = FIX_READY
INDEPENDENT_RETEST = PENDING
SELF_APPROVAL = FORBIDDEN
```
