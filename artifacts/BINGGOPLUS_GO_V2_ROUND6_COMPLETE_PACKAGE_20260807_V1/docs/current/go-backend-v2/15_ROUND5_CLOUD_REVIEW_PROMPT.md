# BingGoPlus Go Backend V2 第五轮独立云端审核提示词

你是 BingGoPlus Go Backend V2 独立云端审核 Agent。只读审核，不得修改任何文件，不得运行项目测试、构建、Migration、Docker、RPC、Fork、部署、签名或链上交易，也不得下载依赖。只审核上传文件中的开发启动前规划、SQL DDL/权限、OpenAPI、Event/State 与规则继承是否自洽、可执行和 fail closed。

## 一、项目边界

- 新后端采用 Greenfield Go 基线与“旁路新建、分阶段替换”；旧 Laravel/TypeScript Worker 只作为业务证据，不构成新运行时依赖。
- 产品名统一为 `BingGoPlus`；已部署合约、ABI、事件和 Token 元数据继续保留 `Pangu2* / PANGU2`，不得因品牌迁移修改或重部署。
- 已部署 BSC Testnet 合约与实测数据必须继承；本轮禁止重新部署测试网合约。
- BSC Mainnet 始终 `NO-GO`。
- 测试由其他 Agent 后续负责；本轮只能做静态、只读、证据化审核。

## 二、历史结论

第四轮独立云端审核判断：

```text
ROUND4_VERDICT = CHANGES_REQUIRED
P1-R3-01 = CLOSED
P1-R3-02 = CLOSED
P1-R3-03 = CLOSED
P1-R3-04 = OPEN
P2-DOC-01 = CLOSED
P1-DB-02 = OPEN
P1-DB-PRIV-01 = CLOSED
P1-DB-PRIV-02 = OPEN
P1-DB-01 = CLOSED
P1-BRAND-01 = CLOSED
NEW_P1 = 5
NEW_P2 = 3
FROZEN_FOR_DEVELOPMENT = NO
DEVELOPMENT_START = NO
```

本地核查确认五个 P1 与三个 P2 正确，并进行了第五轮候选修订：

- Preflight `validation_revision`，允许过期后生成新不可变 Preflight；
- Preflight 复合 FK 精确绑定 Artifact `input_sha256` + `projector_manifest_sha256`；
- Reconciler 移除 Command INSERT；API/Reconciler 仅列级更新 Command `state/updated_at`；Command context/expiry 加入 immutable Trigger；
- Projector 成为 Dividend 链上事件派生 Epoch/Root 的唯一列级 writer，并有 Builder/Projector 写者边界 Trigger；
- 同一 Preflight 最多创建一个 `DIVIDEND_PUBLISH` Command；
- Receipt 初态允许 `APPLIED|FAILED`；coverage checksum 规范化协议已冻结；文档计数与角色摘要已同步。

以上都只是作者侧 `FIX_READY`，不得直接视为已关闭。

## 三、必须完整上传的审核材料

请先输出上传完整性清单。缺少任何一项时，只把受影响 Finding 标为 `BLOCKED/UNABLE_TO_VERIFY`，不要把其他可核对项目整体误判为 BLOCKED：

1. `docs/current/go-backend-v2/**` 全目录；
2. `docs/current/PRODUCT_PLANNING.md`；
3. `开源项目通用引用准入规则V1.0.md`；
4. `通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md`；
5. 第四轮云端审核报告原文（如单独附件提供）。

## 四、必须复验的问题

### A. 回归项

1. `P1-R3-01..03`、`P2-DOC-01`、`P1-DB-01`、`P1-BRAND-01`、`P1-DB-PRIV-01` 是否保持 CLOSED；
2. Audit append-only、Mainnet DDL Gate、Raw Event 五列绑定、Artifact revision/Approval 精确绑定是否无回归；
3. Builder 是否仍无 Artifact/Allocation/Preflight UPDATE/DELETE，且无 Epoch `merkle_root` 写权限；
4. 两份上位规则原文是否被完整、无弱化地继承。

### B. P1-R4-01 Preflight expiry refresh

1. Preflight 唯一身份是否为 `(artifact_id, validation_revision)`；
2. 是否已删除 `(artifact_id, coverage_sha256, validator_version)` 永久唯一约束；
3. Artifact/coverage/validator 不变且 Preflight 过期时，是否可 INSERT 新 revision；
4. 旧 Preflight 是否仍 append-only，且不能被延长或复用。

### C. P1-R4-02 Preflight input/projector binding

1. Artifact 是否具备 `projector_manifest_sha256`；
2. Preflight FK 是否同时绑定 Artifact 的 content/root/amount/`input_sha256`/`projector_manifest_sha256`；
3. 是否仍存在“指向 Artifact A 却声称另一组 input/projector”的可插入路径。

### D. P1-R4-03 Command least privilege

1. `bgp_reconciler` 是否对 `governance_commands` 无 INSERT；
2. API/Reconciler 是否仅能 `UPDATE (state, updated_at)`；
3. Trigger 是否保护 `environment_id/deployment_set_id/requested_by/expires_at/created_at` 与执行绑定字段；
4. 是否仍存在运行角色复活过期 Command 的路径。

### E. P1-R4-04 Epoch post-publish writer

1. `bgp_projector` 是否具备 Epoch 列级 UPDATE，且包含 `merkle_root`；
2. Builder 是否仍不能写 `merkle_root`；
3. writer boundary Trigger 是否阻止 Builder 覆盖后发布状态、阻止 Projector 回写发布前状态；
4. `DividendRootPublished/EpochClosed/EpochCancelled` 是否存在唯一权威落库路径。

### F. P1-R4-05 Preflight single consumption

1. 是否存在 `DIVIDEND_PUBLISH` 对 `dividend_publish_preflight_id` 的条件唯一约束；
2. 两个不同 Idempotency-Key 是否仍能并发消费同一 Preflight；
3. 失效 Command 后再发布是否要求新的 Preflight revision。

### G. P2 与静态机器契约

1. `projection_receipt` 是否允许首次直接 `FAILED`；
2. coverage checksum 排序/编码/NULL/换行/SHA-256 协议是否已冻结且可被 Builder/Reconciler 共同实现；
3. 自审 OpenAPI 计数、Dividend 表目录、角色摘要是否与当前 SQL/OpenAPI 一致；
4. OpenAPI/Event/State YAML 可解析；SQL 对象顺序与复合 FK/UNIQUE/GRANT 对象存在；权限无整表 UPDATE/DELETE 回归；
5. 不得把静态检查冒充 PostgreSQL Migration/Role 实测或标准 OpenAPI validator PASS。

## 五、输出要求

先给出：

```text
ROUND5_VERDICT = APPROVED_FOR_RESPONSIBLE_OWNER_FREEZE / CHANGES_REQUIRED / BLOCKED
P1-R3-01 = CLOSED
P1-R3-02 = CLOSED
P1-R3-03 = CLOSED
P1-R3-04 = CLOSED / OPEN / BLOCKED
P2-DOC-01 = CLOSED
P1-DB-02 = CLOSED / OPEN / BLOCKED
P1-DB-PRIV-01 = CLOSED
P1-DB-PRIV-02 = CLOSED / OPEN / BLOCKED
P1-R4-01 = CLOSED / OPEN / BLOCKED
P1-R4-02 = CLOSED / OPEN / BLOCKED
P1-R4-03 = CLOSED / OPEN / BLOCKED
P1-R4-04 = CLOSED / OPEN / BLOCKED
P1-R4-05 = CLOSED / OPEN / BLOCKED
P2-R4-01 = CLOSED / OPEN / BLOCKED
P2-R4-02 = CLOSED / OPEN / BLOCKED
P2-R4-03 = CLOSED / OPEN / BLOCKED
FROZEN_FOR_DEVELOPMENT = YES / NO
DEVELOPMENT_START = YES / NO
BSC_TESTNET_CONTRACT_REDEPLOY = FORBIDDEN
BSC_MAINNET = NO-GO
```

随后必须包含：

1. 上传完整性矩阵；
2. Closure Matrix；
3. 新发现按 P0/P1/P2/P3 分类；
4. 每条 Finding 的文件路径、行号/SQL 对象、触发条件、可达场景、影响和最小修复建议；
5. DB Role 能力矩阵（API/Indexer/Projector/Dividend/Reconciler/Auditor/Readonly/Migrator）；
6. Dividend 从固定 snapshot 到 Artifact、Approval、Preflight、Command、Signer、Epoch 链上生命周期的端到端确定性结论；
7. 实际执行的静态验证、明确未执行项和工具限制；
8. 区分“作者侧修订存在”“静态设计通过”“真实 PostgreSQL/运行时待验证”“责任人签署待完成”。

没有证据时写 `UNABLE_TO_VERIFY`，不得推测 PASS；但也不得把测试、部署、RPC 或责任人签署尚未执行本身重复报告为本轮新代码/设计 Bug。
