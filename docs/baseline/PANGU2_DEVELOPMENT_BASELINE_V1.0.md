# 盘古2开发基线总文档 V1.1-RC

> Baseline ID：`PANGU2-DEV-BASELINE-V1.1-RC`  
> 本文件是候选基线，不是人工批准、代码授权、审计结论或生产发布许可。

## 1. Executive Summary

当前仓库 `pandy123321/bnb-presale-minimal` 的 README 和 SCOPE_LOCK 仍将项目定义为 **BNB Presale Minimal**，并排除用户端、钱包连接、多项目、Claim、Vesting 等盘古2能力。PR #3 目前为 Draft，只新增本基线文件。因此盘古2仓库策略必须先由人工项目负责人通过 `DR-P2-0001` 决定。

```text
Document Version: V1.1-RC
Document Status: BASELINE_CANDIDATE
Project Start Gate: NEEDS_CONFIRMATION
Production Status: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
Current PR: DRAFT_REQUIRED
```

除本阶段治理文档工作外，PB-S1 至 PB-S6 不得启动。

## 2. Document Control

| Field | Value |
|---|---|
| Project / Stage / Task | `PANGU2 / PB-S0 / P2-S0-DOC-01` |
| Prompt Version | `P2-S0-DOC-OPT-V1.0` |
| Document Owner | `PENDING` |
| Prepared By | `P2-S0-DOC-01 Execution Agent` |
| Reviewed By / Approved By | `PENDING / PENDING` |
| Approval Status / Date | `PENDING_HUMAN_APPROVAL / PENDING` |
| Repository | `pandy123321/bnb-presale-minimal`，候选位置 |
| Repository Decision | `DR-P2-0001` |
| Base Branch / Base SHA | `main / 7aae732ffbbc4ecbc44f5c8ae59f57213a86abd2` |
| Previous Head SHA | `caf39ad458708d6623fd7ca7ed3ff5061431cb74` |
| Spec Path | `docs/baseline/PANGU2_DEVELOPMENT_BASELINE_V1.0.md` |
| Spec SHA | `PENDING` |
| Ruleset Path / SHA | `PENDING / PENDING`，当前 Head 未发现根 AGENTS.md |
| Supersedes | 未批准的 V1.0 候选稿 |
| Referenced Decisions | `NONE_ACTIVE` |
| Open Decisions | `DR-P2-0001` 至 `DR-P2-0010` |
| Effective Scope | 仅治理和开发基线文档 |

## 3. Repository Identity

固定 Head 上已确认：README 声明仓库为 BNB Presale Minimal；SCOPE_LOCK 排除盘古2所需的大部分能力；PR #3 为 Draft 且只变更本文件；根 AGENTS.md 未找到；当前 Head 无 PR Workflow Run 或 Status；`contracts/foundry.toml` 属于原 BNB Presale 工程，不构成盘古2工具链批准；未发现 `contracts/foundry.lock`。

### DR-P2-0001：PANGU2 Repository Strategy

```text
Status: PENDING_HUMAN_APPROVAL
Owner: 人工项目负责人
Options: A 新建独立私有仓库（推荐）/ B 转型当前仓库 / C 新仓库继承部分资产
Blocking: PB-S0 Closeout, PB-S1, PB-S2
Exit: 形成 ACTIVE Decision Record
```

Decision 未批准前，不得修改 README/SCOPE_LOCK，不得初始化盘古2产品代码，不得输出 Project Start Gate GO。

## 4. Rule Priority

```text
ACTIVE Human Decision Record
→ Approved Project Baseline
→ Approved Stage Plan
→ Approved Task Spec
→ Frozen ABI / Event Schema / API Schema / Data Schema
→ Verified Implementation at Fixed SHA
→ Prototype and Reference Documents
→ Historical Documents
```

Finding 只能证明实现不符合已批准规范、要求回到规范并验证修复；Finding 不得改变经济模型、API、权限、事件或状态机。

## 5. Decision Register

| ID | Decision | Status / Owner | Exit | Blocks |
|---|---|---|---|---|
| DR-P2-0001 | Repository Strategy | PENDING / 人工负责人 | 批准 A/B/C | S0 Closeout、S1、S2 |
| DR-P2-0002 | 分红档位 35/30/20/15 | PENDING / 人工负责人 | 确认档位和环境 | S1 Dividend、S3 |
| DR-P2-0003 | 额外6%计税基数 | PENDING / 人工负责人 | 确认整笔或利润部分 | S1 Trade |
| DR-P2-0004 | UNKNOWN 按10% | PENDING / 人工负责人 | 确认产生、解除和税率 | S1 Cost/Trade |
| DR-P2-0005 | Locker期限和到期行为 | PENDING / 人工负责人 | 确认模式、期限、接收方 | S1 Locker、S6 |
| DR-P2-0006 | `_burn`或不可恢复地址 | PENDING / 人工负责人 | 确认销毁口径 | S1 Token |
| DR-P2-0007 | DEX/Router/Pool/Fee Tier | PENDING / 人工负责人 | 确认测试网配置 | S1 Trade/Buyback |
| DR-P2-0008 | 价格源和抗操纵 | PENDING / 人工负责人 | 批准TWAP/Oracle完整方案 | S1 Trade/Cost Closeout |
| DR-P2-0009 | Governance/Timelock/Emergency/Keeper | PENDING / 人工负责人 | 批准角色矩阵和交接 | S1 Governance、S6 |
| DR-P2-0010 | 分红资产和未领取资金 | PENDING / 人工负责人 | 确认资产、Claim和处置 | S1 Distributor、S3 |

## 6. Project Execution Profile

策略为 `PANGU2_FIRST_PLATFORM_READY`：先完成盘古2，只保留低成本边界，不建设多租户、多链、插件或微服务。环境顺序为 `LOCAL → CI → BSC_TESTNET → STAGING → TESTNET_CLOSEOUT`；BSC_MAINNET 始终 `NO-GO`。项目协调 Agent 管 Gate；执行 Agent 实施固定 Task Spec；审核 Agent 只读审核固定 SHA；人工项目负责人批准重大范围、权限、合并和发布。

## 7. Scope 与 Non-Scope

候选范围：盘古2合约套件、Vue DApp/Admin、Laravel模块化单体、PostgreSQL、Redis/Horizon、TypeScript Chain Worker、测试网和 Staging 证据。

非范围：主网、真实资金和生产Secret；多租户、多链、插件、微服务；托管用户私钥或后台代签；管理员改用户资产/成本/分红；自动合并、自动部署和收益承诺。

## 8. Business Parameter Matrix

参数状态只允许 `PROPOSED / TESTNET_ASSUMPTION / TBC / DERIVED / MOCK_ONLY`。没有 ACTIVE Decision 的参数不得标记 FROZEN。

| ID | Parameter | Status / Value / Unit | Decision / Owner | Environment / Mutability | Validation / Mainnet Gate |
|---|---|---|---|---|---|
| P2-P001 | Token Name/Symbol | PROPOSED / PANGU2 / string | PENDING / 人工负责人 | Local-CI-Testnet / immutable deploy | exact string / ACTIVE decision |
| P2-P002 | Supply | PROPOSED / 1B×10^decimals / token wei | PENDING / 人工负责人 | Local-CI-Testnet / immutable | no public mint / audit |
| P2-P003 | Buy Tax | PROPOSED / 400 / bps | PENDING / 人工负责人 | Local-CI-Testnet / capped | conservation / decision |
| P2-P004 | Normal Sell Tax | PROPOSED / 400 / bps | PENDING / 人工负责人 | Local-CI-Testnet / capped | conservation / decision |
| P2-P005 | Profit Sell Tax | PROPOSED / 1000 / bps | PENDING / 人工负责人 | Local-CI-Testnet / capped | 9%+1%+90% / oracle decision |
| P2-P006 | Extra 6% Base | TESTNET_ASSUMPTION / whole amount | DR-P2-0003 / 人工负责人 | Testnet / redeploy | integer invariant / ACTIVE |
| P2-P007 | Dividend Tiers | TESTNET_ASSUMPTION / 35-30-20-15% | DR-P2-0002 / 人工负责人 | Testnet / epoch-versioned | sum100% / ACTIVE |
| P2-P008 | Buyback Amount/Interval | PROPOSED / 0.01 BNB, 60s | PENDING / 人工负责人 | Testnet / deploy parameter | exact wei/time / review |
| P2-P009 | UNKNOWN Tax | TESTNET_ASSUMPTION / 10% | DR-P2-0004 / 人工负责人 | Testnet / rule-versioned | no UI override / ACTIVE |
| P2-P010 | Cost Unit | TESTNET_ASSUMPTION / WBNB wei | DR-P2-0008 / 人工负责人 | Testnet / schema-versioned | unit integer / oracle approval |
| P2-P011 | Locker Mode | TESTNET_ASSUMPTION / deployment fixed duration | DR-P2-0005 / 人工负责人 | Testnet / immutable | duration explicitly supplied / ACTIVE |
| P2-P012 | Locker Duration | TBC / no default | DR-P2-0005 / 人工负责人 | Testnet / immutable | no 365-day assumption / ACTIVE |
| P2-P013 | Burn | TBC | DR-P2-0006 / 人工负责人 | All / immutable | supply accounting / ACTIVE |
| P2-P014 | DEX | TBC | DR-P2-0007 / 人工负责人 | Testnet registry | code/address validation / mainnet-specific |
| P2-P015 | Price Source | TBC | DR-P2-0008 / 人工负责人 | All / governed caps | staleness/deviation tests / mandatory |
| P2-P016 | Dividend Asset | TBC | DR-P2-0010 / 人工负责人 | Epoch-versioned | funding≥root total / ACTIVE |
| P2-P017 | Snapshot Finality | DERIVED / environment profile | PENDING / Stage owner | per environment | canonical block / mainnet review |
| P2-P018 | Prototype Data | MOCK_ONLY | NONE | Local mock only | show MOCK_DATA / forbidden production |

## 9. Contract Responsibility Matrix

| Contract | Responsibility | Forbidden Boundary |
|---|---|---|
| Token | ERC20、供应量、受限结算原语、销毁 | 不报价、不接受伪造买卖上下文 |
| TradeRouter | 买卖路径、deadline、minOut、preview和执行 | 不单独重复扣税，不信任前端税率 |
| CostBasisManager | cost/tracked/UNKNOWN/转账迁移 | 无任意管理员setter |
| FeeVault | Dividend/Support bucket隔离和受限转换 | 非通用金库，无用户提现 |
| SupportPool | 持有BNB并受限回购 | 无任意recipient或call |
| BuybackLocker | 回购批次和到期规则 | 无提前释放和任意提取 |
| DividendDistributor | funded root、proof、claim、防重领 | 不计算排名，不原位改已发布root |
| GovernanceAdapter | typed target/selector allowlist | 禁止任意call/delegatecall |

## 10. Trade and Tax Classification

候选协议使用“官方 TradeRouter + 单一 Tax Settlement Engine”。Router负责编排；Token内部结算只扣一次税。测试网默认拒绝外部用户直接与 Pair 交互，直至独立决定支持方案。

| Path | Allowed / Class | Tax | Cost | Exempt | Event/Test |
|---|---|---|---|---|---|
| Pair→User | NO / direct buy | none | none | no | rejected/bypass test |
| Pair→TradeRouter | YES / DEX buy leg | none | none | system | gross receive test |
| TradeRouter→User | YES / official buy | 4% once | add actual cost/net amount | no | TokensPurchased/conservation |
| User→TradeRouter | YES / sell entry | none here | consumed by settlement | restricted | SellInitiated/no duplicate migration |
| TradeRouter→Pair | YES / official sell | 4% or 10% once | already consumed | system context | TokensSold/split invariant |
| User→Pair | NO / direct sell | none | none | no | rejected/bypass test |
| FeeVault→Router→Pair | YES / fee conversion | no recursive tax | none | system | FeesConverted/bucket exact |
| Pair→BuybackLocker | YES / buyback | no user buy tax | no user cost | system | BuybackExecuted/locked=out |
| User transfer | YES / transfer | none | proportional floor migration | no | CostBasisTransferred |
| System transfer | allowlisted context | none | only explicit hook | yes | forged-context test |
| Add/Remove liquidity | controlled only | none | approved rule or UNKNOWN | system | not buy/sell tests |
| Burn | restricted | none | user burn consumes proportional cost | protocol context | supply/cost invariant |
| Fund Distributor | YES | none | none | system | DividendFunded |
| Distributor→User | YES / claim | none | testnet: zero-cost tracked amount | system | DividendClaimed |

`previewSell`仅预览。真实sell在链上使用同一内部逻辑重新计算成本、价格和税率，验证deadline/minOut/路径/Oracle。税率漂移导致minOut失败时整笔回滚。

## 11. Cost Basis Protocol

成本单位候选为 WBNB wei，token数量为最小单位。tracked为零时cost必须为零。部分卖出和部分转账使用向下取整；全部转出迁移全部余成本；自转账不改变状态。官方买入以实际支付成本和税后到账建仓；系统地址不建立用户仓位；无法证明来源、移除流动性或历史导入产生 UNKNOWN。UNKNOWN只能通过可验证重建、批准迁移或Decision解除，管理员不得任意改写。

价格判断不能只写“DEX报价”。DR-P2-0008必须批准Oracle/Pair、TWAP窗口、观察数、最小流动性、最大spot/TWAP偏差、引用区块、陈旧阈值和fail-closed行为，并测试闪电贷、同区块操纵、sandwich和低流动性。Decision未批准时TradeRouter和CostBasis不得Closeout。

## 12. Dividend and Merkle Protocol

分红资产由DR-P2-0010决定；测试网候选为PANGU2。Snapshot必须保存finalized block number/hash；重组使未发布epoch失效并重算，已发布root进入暂停/更正流程。余额来自canonical Transfer投影；排除地址列表版本化；排序为余额降序、同余额按20-byte地址升序。少于100人按实际名次；空档和整数余数候选进入carry-over。Root发布前校验Distributor资金充足。

已发布Root不得原位替换。无claim时可由Timelock取消并新建epoch；已有claim时通过correction epoch补差。Proof文件记录schema、snapshot、root、total、count和SHA-256。

Merkle Leaf V1候选：

```solidity
bytes32 inner = keccak256(abi.encode(
  block.chainid, address(distributor), epochId,
  address(rewardToken), account, amount
));
bytes32 leaf = keccak256(bytes.concat(inner));
```

类型候选为 `(uint256,address,uint256,address,address,uint256)`。Schema独立固定SHA前不得称为FROZEN。

## 13. Buyback and Locker Protocol

FeeVault转换不得再次产生卖出税；SupportPool输出必须直接进入Locker；Pair→Locker不收用户买入税；回购失败原子回滚。Locker测试网采用 `DEPLOYMENT_FIXED_DURATION`，具体非生产秒数必须由Task Spec给出，不得默认365天。仅SupportPool/BuybackExecutor创建单调batchId；普通转账不创建批次；禁止提前释放和任意管理员提取；解锁接收方由DR-P2-0005决定；状态只允许 `LOCKED→UNLOCKABLE→RELEASED` 或 `PERMANENT`；不变量为 `locker balance >= outstanding batches`。

## 14. Governance and Permission Matrix

| Role | Candidate Admin | Allowed | Forbidden |
|---|---|---|---|
| DEFAULT_ADMIN_ROLE | deployer临时→Timelock | grant/revoke | 资金操作 |
| GOVERNANCE_ROLE | Timelock | 受限参数/registry | 超硬上限、任意call |
| TIMELOCK_ROLE | Timelock | 排队后的allowlisted操作 | delegatecall/任意目标 |
| EMERGENCY_ROLE | 受控EOA/Safe | pause | unpause、资金、改参数 |
| KEEPER_ROLE | testnet keeper | convertFees/自动任务 | 自定义金额/recipient |
| ROOT_PUBLISHER_ROLE | Timelock/受限发布者 | 发布已资金化root | 修改分配/提现 |
| PAUSER_ROLE | Emergency | pause并发事件 | 其他治理 |
| UNPAUSER_ROLE | Timelock | unpause | Emergency不得拥有 |

DR-P2-0009必须固定角色管理员、grant/revoke/renounce、初始化顺序、参数上限、Pause函数列表和测试网/主网差异。GovernanceAdapter禁止通用任意call。

## 15. Environment Profiles

**LOCAL**：chainId 31337；Anvil精确版本由P2-G04固定；仅默认测试账户；Docker PostgreSQL/Redis；一键启动、停止和 `docker compose down -v`；日志脱敏。

**CI**：精确容器和frozen lockfile安装；临时DB/Redis/Anvil；缓存key含锁文件hash；按存在模块运行治理、Schema、合约、API/Worker、DApp/Admin和集成检查；Artifacts包含报告、coverage、ABI/Schema和Head SHA；禁止空报告、continue-on-error和Secret泄露。当前PR无关联Workflow，P2-G06须独立授权创建。

**BSC_TESTNET**：chainId 97；RPC只从Secret/环境读取；Deployer/Governance/Keeper/Emergency/Root Publisher分离；记录地址、code hash、ABI version、部署区块/tx；确认数和snapshot finality版本化；重部署使用新deployment ID；测试流动性、证据和停用runbook完整。

**STAGING**：PB-S6 Closeout必需；使用BSC_TESTNET；独立TLS/API/DB/Redis/Worker/DApp/Admin/日志/告警；固定Artifact发布；数据重置有审计；无生产Secret。

**BSC_MAINNET**：`NO-GO`，只列未来审计、治理、Artifact、Safe/Timelock、流动性、监控、演练和人工批准Gate，不记录真实凭证或部署指令。

晋级均必须固定 Source SHA、Artifact Digest、配置、迁移、ABI、测试证据、回滚和批准角色。P2-G04必须通过版本文件和锁文件固定精确版本，不能只写Node LTS或OZ 5.x。

## 16. Architecture and Module Boundaries

候选为 Laravel模块化单体 + TypeScript Chain Worker + Laravel Horizon Job Worker + Vue DApp/Admin + Foundry，第一阶段不拆微服务。

Chain Worker唯一拥有区块、tx、receipt、log、canonical/finality、reorg和chain cursor；Laravel只消费raw fact/outbox。Laravel Horizon唯一负责业务投影、Snapshot、排名、Merkle、Proof和补偿。Scheduler只派发job。Chain cursor归Chain Worker；业务幂等归handler；chain outbox由Worker生产，business outbox由Laravel生产。使用指数退避、dead-letter、审计补偿、PostgreSQL lease/advisory lock，禁止两个系统处理同一事实任务。

## 17. API Baseline

前缀为 `/api/v1/projects/pangu2` 和 `/admin-api/v1/projects/pangu2`。金额使用十进制整数字符串；响应带project/environment/chain/data_status/block/generated_at。

| API Group | Auth/Permission | Required Contract |
|---|---|---|
| config/status/contracts | Public | registry version、freshness、503恢复 |
| preview-buy/preview-sell | Public | amount/slippage/deadline；quote/tax/minOut/block/expiry；422/503稳定错误 |
| wallet summary/history | Public | address、cursor/limit；indexed freshness和恢复 |
| epoch/proof/buyback/locker | Public | finalized block、root/proof/checksum、分页 |
| auth nonce/verify | Public→Session | nonce一次性、过期、签名、幂等和限流 |
| admin dashboard/sync | Session/RBAC | project scope、freshness、审计 |
| rescan/job retry | OPERATIONS | Idempotency-Key、range/version、202、补偿 |
| epoch snapshot/calculate/root/proposal | OPERATIONS/ROOT_PUBLISHER | 状态机、资金校验、checksum、expected contract |
| audit logs | AUDITOR | append-only、cursor分页 |

每个端点的OpenAPI必须固定鉴权、类型、单位、HTTP码、业务错误、幂等、分页、新鲜度、区块和失败恢复；独立Schema Task固定SHA前本节仅为候选。

## 18. Event Schema Baseline

最低候选事件：`PairUpdated`、`SystemAddressUpdated`、`TokensPurchased`、`TokensSold`、`CostBasisUpdated`、`FeeBucketCredited`、`FeesConverted`、`BuybackExecuted`、`LockBatchCreated/Released`、`DividendFunded`、`DividendRootPublished`、`DividendClaimed`、`Paused/Unpaused`。字段必须包含金额、角色、quote/snapshot block、epoch/token/root/schema version等可审计信息。indexed标记、类型、topic0和ABI编码由P2-G09/PB-S1 Schema固定，变更必须升级版本并同步解析器、前端类型和测试。

## 19. Data Schema Baseline

命名：`chain_transactions`是raw fact；用户/管理链操作使用`chain_operations`，不使用含糊`transactions`；Laravel框架队列表与业务`job_runs`分开；`chain_event_logs`与`pangu2_*`投影分开；迁移唯一来源为 `services/api/database/migrations`，根database目录不得成为第二来源。

关键表必须评估并显式记录：主外键、project_id、environment、chain_id、block_number/hash、tx_hash、log_index、canonical、removed、finality_status、idempotency_key、status、version、created/updated/audit、唯一约束和关键索引。事件唯一键使用 `(chain_id,block_hash,tx_hash,log_index)`；另建立canonical partial unique `(chain_id,tx_hash,log_index) WHERE canonical=true`。重组保留旧记录并置canonical=false/removed=true，再插入新block_hash记录。

核心表：projects/environments/contract_registry；chain_blocks/transactions/receipts/event_logs/transfers/cursors；chain_operations/outbox_events/job_runs/audit_logs；pangu2_trades/cost_positions/cost_movements/fee_snapshots/buybacks/locker_batches/dividend_epochs/snapshot_balances/rankings/allocations/claims。

## 20. State Machines

必须分为 Wallet、Network、Quote、Approval、Signature、Chain Transaction、Indexing、Data Freshness、Claim。每个Task Spec必须固定初始状态、允许/禁止迁移、触发、超时、重试、终止和reorg路径。

候选核心路径：Quote `IDLE→LOADING→READY→EXPIRED/FAILED`；Approval `REQUIRED→SIGNATURE_PENDING→SUBMITTED→CONFIRMED/FAILED/REJECTED`；Chain `CREATED→SUBMITTED→PENDING→CONFIRMED/FAILED/REPLACED/DROPPED`，确认后可因重组进入`REORGED→PENDING/CONFIRMED`；Indexer `STOPPED→STARTING→SYNCING→LIVE/DEGRADED/FAILED`，LIVE可进入REORGING；Claim `NOT_AVAILABLE→AVAILABLE→SIGNATURE_PENDING→SUBMITTED→CLAIMED/FAILED/REJECTED`，CLAIMED可进入REORG_RECHECK。

## 21. Security Baseline

用户私钥只在钱包；Secret不入仓库、日志或DB；资金用整数、CEI、重入保护和固定recipient；治理用target/selector/value allowlist；Oracle/RPC fail-closed；Root发布校验资金/schema/checksum/state；Worker最小DB权限、lease、幂等和reorg；管理写操作鉴权、RBAC、二次确认、审计并显示环境/合约/金额/calldata摘要；主网前独立审计和应急演练。

## 22. Test Matrix

PB-S0：Markdown结构、Decision引用、链接、Secret、Forbidden Path、重复基线。PB-S1：unit/fuzz/invariant、税费路径、成本舍入、Oracle攻击、权限、claim。PB-S2：auth/RBAC、migration、raw fact、cursor、lease、RPC、reorg、outbox。PB-S3：snapshot、同余额排序、少于100人、空档、尘埃、deterministic root。PB-S4：钱包/网络/quote/approval/signature/tx/reorg/claim/mobile。PB-S5：Session/RBAC/Epoch/jobs/audit/proposal。PB-S6：真实BSC_TESTNET买入、两类卖出、转换、回购、锁仓、Root、Claim、RPC故障、重启、重建和Staging回退。

## 23. Stage Plan

| Stage | Goal | Entry | Closeout |
|---|---|---|---|
| PB-S0 | 仓库/治理/版本/环境/Schema | 当前文档 | Approved baseline+Ruleset+Spec+CI evidence |
| PB-S1 | Contracts | PB-S0和相关Decision | ABI/Event/deploy/unit/fuzz/invariant |
| PB-S2 | API Core/Chain Worker | PB-S0 | raw facts/reorg/auth/RBAC/API |
| PB-S3 | Pangu2 Backend | S1 ABI+S2 facts | deterministic projections/root/proof |
| PB-S4 | DApp | S1 ABI+S2/3 API | testnet wallet/state E2E |
| PB-S5 | Admin | S2/3 Admin API | RBAC/audit/proposal E2E |
| PB-S6 | Testnet/Staging | S1..5 accepted | full evidence+review closeout |
| PB-S7 | Platform extraction | S6 accepted | DEFERRED separate decision |

## 24. Task Spec Index

PB-S0实际任务：`P2-G01`仓库Decision、`G02`骨架、`G03`AGENTS、`G04`精确版本、`G05`LOCAL/CI、`G06`Actions、`G07`Secret/Forbidden/Schema检查、`G08`参数Decision、`G09`Schema候选、`G10`Closeout。

后续索引：PB-S1 `C01..C09`（Token、Router、Cost、Vault、Pool、Locker、Distributor、Governance、Integration）；PB-S2 `B01..B06/W01..W02`；PB-S3 `D01..D08`；PB-S4 `F01..F07`；PB-S5 `A01..A07`；PB-S6 `I01..I05`。

每个索引任务当前状态均为 `NOT_EXECUTABLE_PLANNING_RECORD`。独立Task Spec必须包含：Project/Stage/Task/Title/Prompt、Goal、Repository、Base Branch/SHA、Spec Path/SHA、Ruleset Path/SHA、Allowed/Forbidden、Requirements、Tests、Checks、Dependencies、Inputs、Outputs、Closure、Rollback、Open Decisions、Next Role。未来值均为`PENDING_TASK_SPEC`，禁止把索引直接执行。

当前任务完整字段：Repository/Branch/Base如第2节；Allowed仅本文件；Forbidden为contracts/apps/services/packages/database/infra/workflows/lockfiles/README/SCOPE/Secrets；Tests为UTF-8、结构、Decision、Gate、Forbidden、摘要；输出为V1.1-RC、SHA-256、Blob和Head；Rollback仅本文件；Open Decisions为0001..0010；Next Role为人工项目负责人。

## 25. Required Checks Matrix

| Stage | Checks |
|---|---|
| PB-S0 | markdown-lint、baseline-structure、decision-reference、broken-link、secret-scan、forbidden-path、duplicate-baseline |
| PB-S1 | contracts-format/build/unit/fuzz/invariant、abi-drift、secret |
| PB-S2 | backend/worker lint+test、migration-zero、reorg/idempotency、schema-drift |
| PB-S3 | domain-test、dividend-determinism、merkle-checksum、API contract |
| PB-S4 | dapp lint/unit/build/e2e |
| PB-S5 | admin lint/unit/build/e2e、RBAC/audit |
| PB-S6 | testnet-e2e、staging-smoke、artifact-digest、deployment-registry、recovery |

尚不存在的检查标记`NOT_IMPLEMENTED`，不得运行不存在命令；模块一旦存在且受影响，不得通过path filter、空报告或continue-on-error跳过。Workflow只能由独立Task Spec修改。

## 26. Start Gate

| Condition | Current |
|---|---|
| DR-P2-0001 ACTIVE | NO |
| Approved Baseline | NO |
| Spec SHA / Ruleset SHA | PENDING / PENDING |
| Exact Versions/Lockfiles | NO |
| LOCAL/CI Implemented | NO |
| Decisions Tracked | YES |
| Mainnet NO-GO | YES |

```text
Project Start Gate: NEEDS_CONFIRMATION
```

PB-S1/PB-S2均BLOCKED。不得输出GO。

## 27. Closeout Gate

PB-S0 Closeout要求：DR-P2-0001 ACTIVE；人工批准本基线；Spec/Ruleset SHA固定；G02..G09关闭；所有FROZEN（如有）有ACTIVE Decision；所有TBC有责任人和解除条件；Required Checks绑定最终Head；Forbidden Paths未改；审核Agent固定SHA APPROVED；项目协调Agent再决定ACCEPTED。测试网Closeout仍不等于主网上线。

## 28. Open Decisions

开放项为DR-P2-0001..0010，下一责任角色均为人工项目负责人；各自解除条件和阻塞阶段见第5节。任何新的业务、权限、API或状态机不确定事项必须新增Decision ID，不能用Finding或聊天替代。

## 29. Change Log

| Version | Status | Change |
|---|---|---|
| V1.0 | Unapproved candidate | 含未证实GO/FROZEN和仓库冲突 |
| V1.1-RC | BASELINE_CANDIDATE | 增加仓库Decision、去除伪批准、补齐参数/交易/成本/Merkle/Locker/权限/环境/架构/API/Event/Data/状态/测试/任务/Gate |

## Appendix A. Validation Checklist

- [ ] UTF-8且仅一个H1
- [ ] 无无Decision的FROZEN参数
- [ ] TBC/TESTNET_ASSUMPTION有责任人、Decision和解除条件
- [ ] Project Start Gate不是GO
- [ ] 无未批准365天锁仓、主网批准、自动合并或部署
- [ ] PR保持Draft且只修改本文件
- [ ] Workflow、锁文件、产品代码、README和SCOPE未改
- [ ] 输出SHA-256、Git Blob SHA和新Head SHA
