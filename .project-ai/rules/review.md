# BingGoPlus — Review Rules

## 审核模式

项目：`BNB合约` / BingGoPlus。当前产品阶段：`FLAP-F0`。默认只读审核。

当前 Flap 产品证据优先级：**最新 Owner 经济模型变更 Decision > 已签署产品转向 Decision > F1 固定的 Flap 链上事实/ABI/runtime > F2 机器规范 > 阶段文档 > 口头材料**。解释 Legacy PANGU2 时仍使用：**PANGU2 链上事实 > 部署 Commit/ABI > Legacy 机器规范 > 历史文档**。旧审核通过结论在后续 Owner 变更触及其内容时自动降为历史证据，不能授权新 Revision Freeze。

---

## 审核结论（唯一允许的值）

| Verdict | 含义 |
|------|------|
| **APPROVED** | 当前独立审核范围无 P0/P1 且证据可验证；只代表本次审核通过，下一阶段是否允许进入必须读取该 Stage 的专用 Gate，不得仅凭 `APPROVED` 推导 `NEXT_STAGE_AUTHORIZATION` |
| **CHANGES_REQUIRED** | 存在 P0/P1，修复后重新提审 |
| **BLOCKED** | 证据不可验证（Commit 无法访问/Diff 截断/Binary Evidence/角色隔离未证明） |

禁止：`CONDITIONAL YES`、`建议合并`、`基本通过`。

审核 Verdict 必须注明是否授权下一阶段（如 `S1_ALLOWED = YES/NO`）。

Flap F0 的专用 Gate 固定为：

```text
FLAP_F0_REVIEW = APPROVED
-> APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE

F1_ENTRY_AUTHORIZED remains NO until:
EXTERNAL_REVIEW_ADJUDICATION = ACCEPTED
AND
RESPONSIBLE_OWNER_FREEZE = SIGNED
```

因此 F0 独立审核通过后必须先进入责任人冻结签署，不能自动开始 F1。其他阶段也必须以各自专用 Gate 为准。

---

## 严重程度

| 级别 | 定义 |
|:--:|------|
| P0 | 资金损失 / 私钥泄露 / 权限全绕过 / 核心功能无法启动 |
| P1 | Data 不一致 / Fail Open / 认证绕过 / Runtime 与冻结规范冲突 |
| P2 | 证据不可验证(Binary/截断/过期Hash) / 配置缺失 / 计数不一致 |
| P3 | 措辞矛盾 / 可接受偏差 |

**跨文件一致性是 P2 底线，不是 P3 润色**：Manifest Hash 不匹配、文档间计数不同步、矩阵声明状态与 Evidence 冲突 → P2，不是 P3。

---

## 通用审核项（所有 Commit 类型）

1. **Commit 范围** — 是否符合阶段 Allowed Paths。超出范围 → P1。
2. **证据完整性** — SHA 可验证、Diff 完整可读、Evidence 非 Binary、Manifest Hash 匹配。
3. **角色分离** — Design/Review/Adjudication Agent 是否不同。
4. **安全红线** — Mainnet NO-GO、OpenTrading 不得自动、私钥不外泄、不得假造测试结果。
5. **参数生命周期不得绕过** — PANGU2 参数不可变；Flap 参数必须属于文档 28 的目录、支持范围和生命周期。建议默认值不得伪装成已部署事实。

## 跨文件一致性（每次必查）

6. **决策一致性** — Decision Register、Invariant、Compliance Matrix、Stage Evidence 中同一决策的状态/预期必须完全相同。一个文档 PENDING 而另一个 FROZEN → P2。
7. **计数一致性** — 00 status、02 Matrix、测试脚本、Evidence 输出四处数字必须一致。
8. **Hash 一致性** — Manifest Hash、Evidence 文件 Hash、Matrix 引用的 Hash 必须匹配实际文件内容。
9. **SP Evidence 规则** — Test Expected ≠ actual 且 Expected 被人为改成 actual → P1（不是通过）。

---

## Go 与 Flap 设计审核（RT-GATE / 历史 G0-G9 / 当前 F0-F11）

- PostgreSQL 16+ 隔离实例确认
- 8 LOGIN Role 集群权限干净，`bgp_migrator` 不继承任何运行角色
- DDL 0001+0002 执行 exit code=0
- SP 测试 assertion-style（fail-safe），禁止 fail-open
- Evidence machine-readable（TEST_ID|SQLSTATE|VERDICT）
- Manifest Hash 匹配所有 payload 文件
- RT-GATE-02：Primary/Backup RPC 一致，11 合约+Pair runtime code hash 可验证，RPC Secret 不写入证据
- `backend-go/` 不存在时不得声称 Build 通过

## 合约审核

- Reentrancy / Access Control / Oracle fail-closed
- 税收校验和（Buy 400+9600=10000; Launch Sell 2900+100+7000=10000 等）
- 跨合约资金流（buy→settle→feeVault→dividend/support; sell→consumeCost→settleSell→swap）
- 实现 Agent 只能标记 `FIX_READY`，不得标记 `CLOSED`
- Flap 新合约审核必须覆盖 `contracts-flap/src/**`、接口、库、Flap Vault/Factory 规范和直接交互合约
- Guardian 只能触发固定规则动作；不得修改资金配置或任意提款
- 不得通过新 Vault 恢复 CostBasis、动态盈利税、Top100 35/25/25/15 四档或 PANGU2 专用 Settlement；V6 Top100 额外池按新确定性规则审核

## Flap F0 文档审核

- `PRODUCT_MAINLINE = FLAP`、F0 状态和 F1 未授权必须跨文件一致
- 旧 25/26/G2-G9 只能标 Historical/Superseded，不改写历史结论
- 参数目录必须区分创建前、链上不可变、治理可调和单次操作输入
- 新多 Launch Schema/API/Event/State 在 F2 前只能是候选，不得伪装已冻结
- 新 Solidity、测试网签名/广播、平台 Signer、Migration 和 Mainnet 不得由 F0 授权
- Admin Wallet 是当前责任人冻结候选，不得由审核 Agent擅自改成 User Wallet；F1 必须核对 creator/payer/msg.sender/initial buyer 语义
- F10 通用 Staking 与 F11 Legacy Cutover 必须是不同 Commit、审核包和回滚单元
- V6 候选默认值必须一致：Tax 500 BPS；五桶 3000/2500/2000/1500/1000 且和为 10000；Launch 前可调、确认后冻结
- Dividend 必须是所有有效持有人基础池 + Top100 额外池；Top100 排名和同额打破必须确定性，不得恢复 35/25/25/15
- Staking 只能用 Staking Bucket 迁移后受控兑换和可选预充值；其他 Bucket 与 principal 不得支付奖励
- 回购默认 100% Burn，任何非零 Locker 比例必须在 Launch 前固定；回购 Token 不得给触发者
- 开盘保护旧真实基线为 15 分钟/30% 税而非 15% 税；F1/独立 Solidity Gate 未证明时必须 `UNSUPPORTED`
- Vesting 必须是独立预充值、不可铸币、不可复用回购 Locker；没有实际 Token 到账不得进入 ACTIVE
- EarlyUnstake 必须精确核对 `principal liability decrease = full principal`、`user return = net`、`penalty + forfeited unclaimed reward -> same Pool available Reward Reserve`，且无外部 Recipient/重复入账
- Dividend/Top100 必须排除全部 custody 地址；Staking principal 只能按 staker 计一次；Vesting V1 未释放量不得参与
- BGPlusVaultFactory V1 creation fee/revenue commission 必须为 0，且不得接收 RevenueVault outflow；外部 Flap/Gas 费用必须单独展示
- 审核 Finding 必须包含具体修改位置、步骤、约束、验收和回归检查；只报问题不提供解决方案时审核不完整

## 前端审核

- CSS tokens 完整性 / 合约地址一致性 / 3 页路由无旧残留
- Trading-disabled 时无图表、无倒计时、按钮 disabled
- 所有 `<button>` 有 `type="button"`

---

## Go V2 审核历史（已完成 10 轮）

| 轮次 | Verdict | 关键关闭 |
|------|------|------|
| Round1~8 | 逐轮推进 | Raw Event 无 PROJECTED / Dividend Snapshot 固定区块 / 品牌统一 |
| Round9 | APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE | P1-R8-01/02 + P1-R4-02 + P1-R6-01 + P2-R6-01/02 |
| Round10 | APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE | P2-R9-01 |

## RT-GATE-01 外部审核历史

| Record | Commit | Verdict |
|------|------|:--:|
| #425 | `822edc9` | 2 P1 + 3 P2 |
| #426 | `8f2295c` | 建议合并 |
| #427 | `1562586` | 2 P1 + 2 P2 |
| #428 | `3cbc808` | 3 P1 + 2 P2 |
| #429 | `617b536` | 1 P1 + 3 P2 |
| Fix Cycle 3-5 | `12a2676`~`6039ba2` | 全部 Finding 已修复，90/90 PASS |

## 信息来源
- `docs/current/DOCUMENT_REVIEW_RULES_V1.0.md`
- `docs/current/go-backend-v2/`
- AI Code Review Records #425~#429
