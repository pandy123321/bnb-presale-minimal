# BingGoPlus V2 通用规则继承与开发门禁

状态：`MANDATORY / FREEZE_CANDIDATE`

适用规则：

1. [开源项目通用引用准入规则V1.0.md](../../../开源项目通用引用准入规则V1.0.md)
2. [通用智能合约安全开发风险控制与漏洞治理规范 V1.0.md](../../../通用智能合约安全开发风险控制与漏洞治理规范%20V1.0.md)

这两份规则是 BingGoPlus 新基线的上位门禁，不因 Go 重写、测试网已部署、旧代码已有审核或候选项目知名而豁免。发生冲突时取更严格要求。

## 1. 开源引用准入

### 1.1 分类

- `REFERENCE_PROJECT`：只研究中立需求、状态、失败模式和指标；不复制代码、目录、接口名、文案或独特结构。
- `ADOPTION_CANDIDATE`：完成初筛，但不能下载、安装或提交。
- `CONDITIONAL_ADOPTION_CANDIDATE`：许可证/集成边界有额外风险，必须法律与安全复核。
- `APPROVED_DEPENDENCY`：精确 release/commit、许可证、POC、TCO、SBOM、回滚和人工 Decision Record 全部批准。
- `REJECTED`：不得进入代码、镜像或生成链。

执行 Agent 不得自批。没有可追踪的 `APPROVE_DOWNLOAD` 时，所有候选保持 no-download。知名项目、GitHub Star、已开源或其他项目使用不构成批准。

### 1.2 强制证据

每个正式依赖必须冻结：

- upstream、精确 tag/release/commit、发布时间和维护状态；
- direct/transitive license、NOTICE、生成代码与链接义务；
- Security Policy、Advisory/CVE 与当前处置；
- 实际 import 的 package，不以整个仓库模糊批准；
- POC、benchmark、12 个月 TCO、运行故障与退出成本；
- SBOM、版本升级/回滚计划、Decision Owner；
- 禁止浮动 branch、`latest`、来源不明压缩包和未审 submodule。

LGPL/MPL/EPL 等条件许可证必须验证静态链接、文件修改、分发、源码/重链接义务；GPL/AGPL/SSPL/BSL/source-available 默认不进入生产，除非上位规则规定的例外审批完整通过。

### 1.3 供应链 Gate

- 开发、CI、审核、发布使用相同版本与生成输入；
- OpenAPI、SQL、ABI、生成工具、Go module、容器 base image 全部固定；
- 生成 SBOM、许可证清单、NOTICE、Secret/Dependency 扫描；
- 审计后不自动升级；升级视为新采用决策并重新审核；
- 研究结论必须是项目自有的中立规格，不能把上游实现当模板复制。

## 2. 智能合约安全规范在 Go V2 的继承

Go 重写不修改合约，但它负责索引、报价、分红构建和治理交易，因此仍处于资金与控制面。以下要求必须进入设计：

### 2.1 规格、资产与权限

- 绑定已部署 Commit、bytecode、constructor、roles、address、tx/block/hash；
- 建立 Token、BNB/WBNB、Fee bucket、Support、Locker、Dividend reserve、Staking reserve/liability 资产清单；
- RBAC deny-by-default；API/Indexer/Projector/Builder/Reconciler/Signer/DB Role 分离；
- 不允许单一 EOA、单个 API 进程或任意 calldata 控制全部资金与角色；
- 开盘、Pause/Unpause、Whitelist、Pair/System、Fee conversion、Dividend、Staking 等动作有显式权限与审计。

### 2.2 经济与会计

- 后端不重算税率替代合约，不把 UNKNOWN 降为低税；
- Preview 与 Execute 绑定部署 Router、buyer/seller、observed block/hash；
- FeeVault bucket 和实际余额、Dividend reserved/carry、Staking reserve/liability 持续 reconciliation；
- 分红使用固定 snapshot、Top 100、35/25/25/15、Pull Claim、Merkle proof，不做链上遍历/Push；
- 回购仍由合约强制 0.01 BNB/60 秒、slippage、deadline、Oracle、Locker recipient；
- 数量用 `big.Int/numeric(78,0)`，每个 rounding/dust/carry 规则明确且可重放。

### 2.3 Oracle、DEX 与 MEV

- Oracle stale/LIQUIDITY_LOW/deviation/zero reserve 全部 fail closed；
- 不用 spot price 代替部署 TWAP；
- Quote/Command 固定 slippage、deadline、path、target、selector 和最大数量；
- 多 RPC 结果冲突不静默选一个；
- 不开放 arbitrary target/call/delegatecall；
- permissionless update/buyback/release 仍由合约验证所有上限，后端不把 keeper 当安全边界。

### 2.4 Reentrancy/DoS/Gas 对应的服务端控制

- 服务端不批量向所有 Holder 推送链上交易；
- Indexer、Builder、API pagination 和 Job batch 全部有上限、Cursor 和可恢复 checkpoint；
- Dividend 用 off-chain 计算 + on-chain Merkle 验证；
- 单用户 proof/claim 失败不阻断其他用户；
- RPC、DB、Signer 故障有 bounded retry/dead letter，不无限循环或吞错。

### 2.5 部署、监控与事件响应

- 部署脚本历史证据与当前链上 readback 分开；广播回执成功不等于当前 bytecode/role 安全；
- 部署后检查 source verification、runtime bytecode、constructor、roles、pause、fee、oracle、router、treasury、allowance 和 frontend address；
- 监控 Role/Owner/Pause/Fee/Oracle/Liquidity/Buyback/Dividend/Staking/余额守恒和异常交易；
- 安全事件分 SEV-0..3，保全证据、保护剩余资产、外部复核、人工批准恢复；
- 不删除异常证据，不用未经验证的紧急升级，不私自转移用户资产。

## 3. 漏洞与风险台账

### 3.1 漏洞状态

沿用：`NEW / TRIAGED / CONFIRMED / DISPUTED / FIX_IN_PROGRESS / FIX_READY / RETESTING / RESOLVED / RISK_ACCEPTED / DUPLICATE / NOT_APPLICABLE / REOPENED / DISCLOSED`。

关闭必须同时具备 Fix Commit、原 PoC 不再成功、回归/不变量、工具复测、独立审核、残余风险和受影响部署处置。仅“代码已改”不得关闭。

### 3.2 风险状态

沿用：`OPEN / MITIGATING / MONITORING / ACCEPTED / TRANSFERRED / AVOIDED / CLOSED`。每项记录 Asset、Likelihood、Impact、Existing/Required Controls、Owner、Decision Owner 和 Review Date。

### 3.3 现有合约记录继承

- 旧审计 `docs/current/CONTRACT_SECURITY_AUDIT.md` 绑定 commit `e2c09c5`，不是部署 commit `3ef50b6` 的完整批准；
- 部署后的 source/interface/script 修复必须区分：影响 runtime、只影响后续部署脚本、只影响测试/文档；
- `P1-002 preview mismatch` 后续源码已修复，但需要部署字节码/ABI readback 才能确认测试网实例包含；
- `P1-001 staking reward funding/cost basis` 及 FeeVault 等既往风险不能因“18 项已完成”口头汇总自动 RESOLVED；
- post-deploy Bootstrap/Finalize/OpenTrading 脚本加固只保护未来执行，不能反向改变已发生部署；
- 所有未具备关闭证据的项进入风险/漏洞台账，并在 Admin 展示或 API fail closed。

## 4. 测试范围的处理

用户已明确本轮不规划和执行测试，由独立 Agent 在实现后接管。因此本轮：

- 不运行 Unit/Fuzz/Invariant/Fork/Mutation/CI；
- 不把“未测试”伪装成通过；
- 数据库/API/事件/状态机冻结可以完成，但不能据此批准 Mainnet；
- 安全规范中的 Unit/Fuzz/Invariant/Fork/Static/External Audit 仍保留为后续 Testnet Release/Mainnet 硬 Gate，不被删除或降级；
- 测试 Agent 必须接收 deployment commit、业务不变量、风险台账和本目录机器规范作为输入。

## 5. Mainnet NO-GO

本基线只允许 BSC Testnet。以下任一存在时均 NO-GO：

- 规格、资产清单、依赖、编译/生成输入或 deployment evidence 未冻结；
- runtime bytecode、roles、pause、oracle、fee、allowance、frontend address 未做固定区块 readback；
- P0/P1 未关闭，P2 未修复或未经人工接受；
- 测试、静态分析、内部/外部审核、SBOM、部署演练、监控、事件响应未通过；
- Signer、Multisig/Timelock、Secret、用户退出或人工批准未就绪；
- 审计 commit、部署 commit、bytecode 不一致；
- Mainnet 私钥或 RPC Secret 进入代码、`.env` 提交或普通服务器。

`APPROVED_WITH_CONDITIONS / UNDER_REVIEW / PARTIAL / PENDING / BLOCKED / UNKNOWN` 均不得被解释为 Mainnet 批准。

## 6. 决策记录清单

开发前必须签署：

| Decision ID | 内容 | Owner |
|---|---|---|
| DR-BRAND-01 | 产品名 BingGoPlus；链上 `Pangu2*` 身份不改 | 产品 + 合约 |
| DR-CONTRACT-01 | 测试网 ACTIVE deployment set 与 readback | 合约 + 安全 |
| DR-BIZ-01 | 经济/控制继承矩阵 | 产品 + 合约 + 安全 |
| DR-BIZ-02 | Dividend 有效持币量、排除、尾差、空档 | 产品 + 数据 |
| DR-DB-01 | SQL、唯一键、Reorg、重建 | 数据 |
| DR-API-01 | OpenAPI、Auth/RBAC、Command | 前端 + 后端 + 安全 |
| DR-EVENT-01 | ABI/Event/State/confirmation | 合约 + 数据 + 运维 |
| DR-OSS-* | 每个开源依赖与下载授权 | 开源 + 法律 + 安全 |
| DR-ENV-01 | 环境、Signer、Secret、单写者、回滚 | 平台 + 安全 |
| DR-CUTOVER-01 | Endpoint 分域切换与旧系统停用 | 产品 + 工程 + 运维 |

## 7. Stage Exit 证据

每阶段记录固定 Commit、文件、工具/依赖版本、输入 Hash、命令、结果、发现、残余风险、Reviewer、Decision Record 和 Verdict。开发 Agent 不能批准自己的 Stage Exit；安全/测试/发布由独立审核者接管。
