# BingGoPlus — CROSS-STAGE MANDATORY RULES

> 以下 26 条规则对所有阶段（历史 G0-G9、当前 Flap F0-F11、RT-GATE、合约修复）全局生效。完整 68 条规则见 `docs/current/RULES_MASTER.md`。Agent 违反任一规则 = 审核直接 BLOCKED。

## 执行边界

1. **一次一个阶段** — 实现完成后必须先停止开发，生成提审包并交付用户手动提交；用户回传独立审核报告后，完成外部结论二次裁决和证据登记。全部推进条件满足后，才可自动进入已冻结的下一阶段。范围外、证据不足或结论无法判断时必须暂停并请求人工确认。
2. **阶段独立 Commit** — 一个阶段 = 一个 git commit。不同阶段不合并。
3. **Commit 范围受控** — 仅含本阶段允许的文件。Flap F0-F2 不可含业务实现，RT-GATE 不可含 Solidity。
4. **每阶段结束 = 外部审核闸门** — 等待 APPROVED 后才允许下一阶段。CHANGES_REQUIRED = 修后重提。

## 证据规则

5. **Commit SHA 可独立验证** — 完整 40 位，远程可解析。
6. **Diff 完整可读** — 不截断、不 Binary。Evidence UTF-8 纯文本。
7. **Commit message 不是证据** — 声称 ≠ 内容验证。
8. **Payload 完整性** — Manifest Hash 与文件内容一致。外置，不 self-hash。

## 角色与权限

9. **实现 Agent ≠ 独立批准** — 只能标 `FIX_READY`/`INDEPENDENT_RETEST_PENDING`。不可标 `CLOSED`/`APPROVED`/`PASS`。
10. **Design ≠ Review ≠ Adjudication Agent** — 三者必须不同 session/identity。
11. **仅修改 Allowed Paths** — 范围外问题只记录，不顺手扩展。

## 安全红线

12. **Mainnet NO-GO** — chain 56 永久禁止。
13. **PANGU2 OpenTrading 不得重复** — 现有部署只读。Flap Launch 必须独立审批和钱包/批准 Signer 签名，不能由 CI、启动脚本或定时任务触发。
14. **合约不得重部署未经批准** — 源码修改是候选，不可标"已链上生效"。当前合约 admin 已 renounce（预期行为）。
15. **经济参数按版本和生命周期冻结** — PANGU2 已部署参数不可改；Flap 参数只允许按文档 28 的目录、边界和生命周期设置，禁止链上确认后改写不可变字段。
16. **私钥/Secret 不外泄** — 不入代码、日志、Commit、文档、测试。
17. **不得伪造测试** — 未运行写 `NOT_RUN`。Expected≠Actual 时不可改 Expected 后标 PASS。
18. **不得吞错误** — 不用 `|| true`/`continue-on-error`/空 catch。

## 与旧系统的关系

19. **Laravel 代码冻结** — 不修不补不新增；Go 是唯一目标后端。旧运行时退役只允许在 Flap F11 独立 Cutover Gate 处理，不得把“停止开发”误写成“已经完成运行时下线”。
20. **旧合约地址组永久废弃** — `0xaf2bD8...` 系列永不激活。

## Flap 当前主线

21. **新 Token 必须从 Flap 发出** — 只允许 F1 固定并验证过的 Portal/VaultPortal；禁止私有 Factory 或 PANGU2 脚本冒充 Flap。
22. **PANGU2 是只读遗产** — 不改、不重部署；CostBasis、动态盈利税、专用 Router/Settlement、Whitelist、Top100 35/25/25/15 四档和专用 Staking 实现不得进入新产品。开盘保护、Top100 奖励、Staking 只能按文档 28 的 Flap 兼容模型重做。
23. **禁止任意链上调用** — 只能使用固定 Chain、target、selector、ABI、参数 schema、value 上限和 request hash；不接受任意 calldata。
24. **Guardian 最小权限** — 只允许触发固定规则动作，不得改 BPS、收款地址、管理员、Merkle Root 或任意提款。
25. **当前阶段是 Flap F0** — F0 只改文档、规则和上下文；独立审核与 Owner Freeze 前不得写 Go/SQL/OpenAPI/前端/Solidity。
26. **外部审核由用户手动提交** — 执行 Agent生成提审包、Hash 和提示词，不寻找审核工具、不伪造任务 ID；收到报告后仍必须二次裁决。该规则适用于当前及后续阶段，直至责任人书面修改。

## 错误示例（Agent 常见违规，直接 BLOCKED）

```
❌ 一次提交 126 个文件 → BLOCKED
❌ Commit message 写 "P2-01~P2-05 final"，Diff 截断 → BLOCKED
❌ 测试失败后把 Expected 改成 FAIL 报 PASS → BLOCKED + P1
❌ SP Evidence 编码为 Binary → BLOCKED
❌ 实现 Agent 自标 "INDEPENDENT_REVIEW = APPROVED" → BLOCKED
❌ Manifest Hash 过期 → 不计入 PASS
❌ 一个 Commit 同时改 S0 Evidence + 权威 baseline → BLOCKED
❌ "先通过以后再查" → BLOCKED
```
