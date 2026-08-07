# S6 — Dividend Epoch 发布终态和取消边界

```text
Stage ID: PANGU2-V2-S6
Findings: P2-DIV-01
Prerequisite: S5 APPROVED_CODE_ONLY
Macro Gate: none
```

## 1. 目标

确保 Governance 不能在 Published Epoch 的 claimStart 前撤销已经通过两步 commitment 发布的分配。默认只允许 claimEnd 后、且尚无 Claim 的 Epoch 被取消并转入 carry。

## 2. Allowed Paths

```text
contracts-v2/src/DividendDistributor.sol
contracts-v2/src/interfaces/IDividendDistributor.sol
contracts-v2/src/libraries/MerkleLeafV1.sol（仅接口证明确需时，原则上不改）
contracts-v2/test/*Dividend*.t.sol
remediation/evidence/S6_*.md
```

Forbidden：更改 30 天窗口、Merkle leaf schema、commitment 字段、reward token、Governance/Root Publisher 分工或 FeeVault funding。

## 3. 实现要求

1. `cancelUnclaimedEpoch()` 仅在 `block.timestamp > claimEnd` 时允许。
2. 仍要求 status=PUBLISHED 且 `totalClaimed==0`。
3. claimStart 前、claimStart、claimEnd 以及窗口内全部不能取消。
4. Cancel 后状态不可逆，reserved 扣减与 carry 增加必须守恒。
5. 不引入 Governance 直接提取 reserved Token 的路径。
6. 不默认增加 emergency pre-start cancel；如业务要求，必须回到 S0 做独立经济/治理决策，采用不同角色、Timelock、原因和事件。
7. 保持 commitment 绑定 chainId、distributor、epochId、rewardToken、root、amount、snapshot、窗口、schema 和 checksum。
8. 保持 claimed 状态在外部 transfer 前更新和 `nonReentrant`。

## 4. 测试要求

- publish 后、claimStart 前 cancel 必须失败；
- claimStart、claimStart+1、claimEnd、claimEnd+1 精确边界；
- claimEnd 后无 Claim 可取消；已有任意 Claim 不可取消；
- CLOSED/CANCELLED 不可重开或重复取消；
- reserved/claimed/carry 守恒；
- commitment consume/revoke/publish/cancel 组合；
- 跨 chain/distributor/token proof 重放仍失败；
- Fuzz：epoch 时间、amount、claim 顺序；
- Invariant：开放 Epoch reserve 总额等于 `totalReservedClaims`。

## 5. 阶段审核重点

- 时间边界是否 off-by-one；
- 取消是否能在 pause 状态成为治理绕过；
- Root Publisher 与 Governance 权限是否仍分离；
- 新事件是否足够追踪；
- 不把链下 Top 100/分层排名误加入合约逻辑。

## 6. 退出条件

```text
P2-DIV-01 = CLOSED_CODE_ONLY
CLAIM_WINDOW = 30 days
COMMITMENT_SCHEMA_CHANGED = NO
IMPLEMENTATION_COMMIT_SHA = full 40-char SHA
CORE_SOLIDITY_BUILD = PASS
INTERFACE_IMPLEMENTATION_MATCH = PASS
COMPILE_ERRORS = 0
INDEPENDENT_REVIEW = APPROVED_CODE_ONLY
REVIEW_VERDICT_CONFIRMED = YES
S7_ALLOWED = YES only if CORE_SOLIDITY_BUILD = PASS
DEPLOYMENT_APPROVAL = NOT_GRANTED
```
