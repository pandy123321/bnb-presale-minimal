# 盘古2开发基线总文档 V1.0

# 盘古2开发总基线 V1.0

## 0. 文档控制

| 字段 | 基线值 |
|---|---|
| Baseline ID | `PANGU2-DEV-BASELINE-V1.0` |
| Project ID | `PANGU2` |
| 项目名称 | 盘古2链上经济系统 |
| 开发策略 | `PANGU2_FIRST_PLATFORM_READY` |
| 目标网络 | BNB Smart Chain Testnet 优先 |
| 主网状态 | `NO-GO` |
| 文档状态 | `DEVELOPMENT_BASELINE` |
| 适用角色 | 产品、Solidity、前端、后端、测试、安全、运维、审核 |
| 生效日期 | 2026-08-01 |

本基线用于启动盘古2开发、联调、审核和测试网验收。它不构成收益承诺、法律意见、第三方安全审计结论或主网上线批准。

## 1. 项目决策

### 1.1 核心路线

采用以下路线：

```text
冻结最小开发基线
→ 快速完成盘古2合约与系统
→ BSC测试网跑通完整闭环
→ 从真实实现中抽取公共能力
→ 接入第二项目验证
→ 再升级为多项目平台
```

第一阶段不得为了未来平台化而提前建设复杂插件系统、动态经济模型、多租户管理、多链适配或微服务体系。

### 1.2 本期必须交付

- 盘古2智能合约套件及完整Foundry测试。
- 用户端DApp：主页、买卖、分红、托底、资产与交易状态。
- Laravel后端API与管理API。
- BSC链上Indexer、交易确认、重组处理与任务Worker。
- 运营管理端：总览、合约、交易、回购、分红、任务、告警、权限和审计。
- 测试网部署、全链路测试、验收证据与风险清单。

### 1.3 本期明确不做

- 多项目创建器和项目模板市场。
- 动态加载任意经济模型的插件系统。
- Ethereum、Polygon、Arbitrum等多链接入。
- 生产主网部署、真实生产资金操作或自动发布。
- 平台代替用户保管私钥、签名或转移用户钱包资产。
- 固定收益、保本、价格上涨或自动赚钱承诺。

## 2. 规则优先级

```text
ACTIVE Decision Record / 人工签署参数冻结表
→ 本基线包 V1.0
→ 已关闭并在固定SHA验证的审核 Finding
→ 合约 ABI / Event Schema / API Schema
→ 原型
→ 历史文档
```

任何原型中的地址、余额、价格、Safe门槛、Timelock时长、锁仓期限和模拟数据都不能反向成为正式参数。

## 3. 当前Gate

| 对象 | 状态 | 说明 |
|---|---|---|
| 开发总基线 | GO | 可作为阶段启动输入 |
| 盘古2经济模型 | CONDITIONAL GO | TBC参数须按本文测试网假设执行并留可替换边界 |
| 智能合约开发 | CONDITIONAL GO | 参数冻结表签署后进入正式实现 |
| 后端与Worker | GO | 可先开发公共骨架和链上事实层 |
| 用户端DApp | CONDITIONAL GO | 依赖ABI、地址和预览接口 |
| 运营管理端 | CONDITIONAL GO | 依赖管理API和权限矩阵 |
| BSC测试网集成 | NO-GO | 合约、后端、DApp和管理端阶段未关闭 |
| BSC主网 | NO-GO | 未完成审计、压力验证、治理和发布审批 |

## 4. 不可违反的系统原则

1. 用户资产操作由用户钱包签名，后台不得代签。
2. 税率、资金去向、销毁和回购金额由合约约束，不以后台数据库为准。
3. 前端只展示合约或可信API返回，不自行判定卖出税率。
4. 链上原始事实与业务投影分开保存。
5. 金额使用最小单位整数，禁止浮点数参与资金计算。
6. 所有链上写操作必须可追踪交易哈希、区块、确认数和最终状态。
7. 所有管理写操作必须进入审计日志。
8. 所有定时任务必须支持幂等、重试、失败记录和人工补偿。
9. 项目代码保留低成本平台化边界，但不得提前过度抽象。
10. 测试网通过不等于主网可用。

## 5. 开发完成定义

“盘古2完成”至少意味着以下测试网闭环全部有证据：

```text
部署合约
→ 初始化角色与参数
→ 创建交易对并添加测试流动性
→ 用户连接钱包
→ 买入并记录成本
→ 普通卖出4%
→ 触发10%卖出状态
→ 税费分桶
→ 税费兑换BNB
→ SupportPool收到BNB
→ 0.01 BNB回购
→ 回购代币进入Locker
→ 创建Epoch与快照
→ 计算前100名和四档分配
→ 生成并提交Merkle Root
→ 用户领取
→ DApp、后台和链上数据一致
```

任何一步仅用Mock通过，不能视为测试网闭环完成。


---

# Project Execution Profile

## 1. 项目标识

```text
Project ID: PANGU2
Project Name: 盘古2链上经济系统
Baseline ID: PANGU2-DEV-BASELINE-V1.0
Delivery Strategy: PANGU2_FIRST_PLATFORM_READY
Target Environment: BSC_TESTNET
Production Status: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
```

## 2. 技术栈基线

| 层级 | 固定技术 | 约束 |
|---|---|---|
| 智能合约 | Solidity 0.8.24、OpenZeppelin 5.x、Foundry | 版本写入配置并锁定 |
| 用户端 | Vue 3、TypeScript、Vite、Pinia、viem、Reown AppKit | 移动端优先 |
| 管理端 | Vue 3、TypeScript、Vite、Ant Design Vue | 与用户端共享类型，不共享业务页面 |
| 后端API | Laravel 13、PHP 8.4、Composer 2 | 模块化单体 |
| 数据库 | PostgreSQL | 金额用numeric(78,0)或字符串DTO |
| 缓存/队列 | Redis、Laravel Horizon | 任务必须幂等 |
| 链上Worker | Node.js LTS、TypeScript、viem | 独立进程，版本在仓库初始化时锁定 |
| 合约测试 | Forge Test、Fuzz、Invariant | 不允许仅Happy Path |
| 前端测试 | Vitest、Vue Test Utils、Playwright | 覆盖钱包和交易状态 |
| 后端测试 | PHPUnit/Pest | 覆盖API、任务、权限和数据一致性 |
| 基础设施 | Docker Compose（本地/测试）、Nginx | 主网基础设施不在本期 |

禁止在任务过程中无关升级主版本。依赖变更必须有明确原因、锁文件Diff和兼容验证。

## 3. 仓库基线

```text
pangu2/
├─ contracts/                 # Foundry合约、脚本、单元/Fuzz/Invariant测试
├─ apps/
│  ├─ dapp/                   # Vue3用户端
│  └─ admin/                  # Vue3管理端
├─ services/
│  ├─ api/                    # Laravel模块化单体
│  ├─ chain-worker/           # 区块、日志、确认与重组
│  └─ job-worker/             # 快照、排名、Merkle和补偿任务
├─ packages/
│  ├─ abi/                    # ABI、事件、地址清单
│  ├─ api-types/              # OpenAPI生成或共享DTO
│  ├─ domain/                 # 状态、错误码、常量
│  └─ ui/                     # 低耦合公共组件
├─ config/
│  └─ pangu2/                 # 环境与合约注册配置
├─ database/
│  ├─ migrations/
│  └─ seeds/
├─ infra/
│  ├─ docker/
│  ├─ nginx/
│  └─ monitoring/
├─ docs/
│  ├─ baseline/
│  ├─ decisions/
│  ├─ specs/
│  ├─ api/
│  └─ test-evidence/
└─ AGENTS.md
```

## 4. 模块边界

### 4.1 可复用Core

只包含已经明确会复用且不包含盘古2规则的能力：

- 钱包Nonce与签名认证。
- 合约地址和ABI注册。
- 区块、交易、Receipt、Event Log和Token Transfer索引。
- 统一交易状态。
- RBAC、审计日志和系统告警。
- 队列任务、幂等、重试与死信。
- API统一响应、分页、错误码和数据新鲜度。

### 4.2 Pangu2业务模块

必须包含：

- 成本基准与可追踪余额。
- 4%与10%卖出状态。
- 税费分桶及资金流。
- 前100名和35/30/20/15分红。
- Epoch、快照、Merkle和领取。
- 0.01 BNB回购、60秒间隔和Locker。

禁止将上述规则放入通用Core。

## 5. 工程规则

- 默认分支、Base SHA、Allowed Paths和Forbidden Paths由每个Task Spec固定。
- 每个任务必须绑定Task ID、Prompt Version、Required Tests和Closure Conditions。
- 真实生产路径优先于辅助函数测试。
- 禁止无关重构、全仓格式化、目录移动或依赖升级。
- 新增共享抽象前必须至少有两个真实调用点；盘古2第一阶段允许保留模块边界但不强制插件化。
- 合约ABI变更必须同步更新ABI包、事件Schema、后端解析器、前端类型和测试。
- 数据库迁移只能向前执行；破坏性迁移必须有单独Decision Record和回滚方案。

## 6. 环境基线

| 环境 | 用途 | 数据 | 写链 |
|---|---|---|---|
| LOCAL | 开发、Anvil和Mock RPC | 可重置 | 仅本地 |
| CI | 自动测试 | 临时 | Anvil/测试容器 |
| BSC_TESTNET | 集成和验收 | 受控测试数据 | 允许测试钱包 |
| STAGING | 可选的前后端预发布 | 测试网数据 | 仅测试网 |
| BSC_MAINNET | 生产 | 真实链上数据 | 本期禁止 |

## 7. 治理执行

```text
项目协调Agent：阶段启动、阶段阻塞、阶段Closeout衔接
执行Agent：开发、自测、Push、PR和审核输入
审核Agent：固定Head SHA只读审核、Finding和Closeout
人工项目负责人：重大范围、权限、合并和发布决定
```

正式审核必须绑定固定SHA。任何审核后新增提交都会使原审核结论失效。


---

# 业务规则与参数冻结基线

## 1. 参数状态

| 状态 | 含义 | 开发处理 |
|---|---|---|
| FROZEN | 已人工确认，可直接实现 | 不得擅自修改 |
| TESTNET_ASSUMPTION | 测试网采用的暂定规则 | 必须集中配置并允许主网前替换 |
| TBC | 未确认 | 不得写死为生产结论 |
| DERIVED | 由合约或公式派生 | 前端/后台只读展示 |
| MOCK_ONLY | 仅原型数据 | 不得进入真实接口或数据库种子 |

## 2. 经济模型冻结矩阵

| 参数 | 状态 | 基线值/规则 | 实现责任 |
|---|---|---|---|
| Token名称/符号 | FROZEN | PANGU2 | Token合约 |
| 总供应量 | FROZEN | 1,000,000,000 PANGU2 | Token合约一次性铸造 |
| 公开增发 | FROZEN | 禁止 | Token合约 |
| 买入协议税 | FROZEN | 4% | Token/FeeVault |
| 买入税用途 | FROZEN | 前100名分红池 | FeeVault Dividend Bucket |
| 普通卖出总税 | FROZEN | 4% | previewSell与Token |
| 普通卖出税用途 | FROZEN | 4%进入托底Bucket | FeeVault Support Bucket |
| 盈利状态卖出总税 | FROZEN | 10% | previewSell与Token |
| 盈利状态税流向 | FROZEN | 9%托底、1%销毁、90%兑换 | 合约强制 |
| 额外6%计税基数 | TESTNET_ASSUMPTION | 按整笔卖出代币数量计算 | 主网前人工确认 |
| 前100名档位 | FROZEN | 1-10:35%；11-30:30%；31-60:20%；61-100:15% | 分红计算 |
| 档内分配 | FROZEN | 按有效持币量比例 | 链下计算+Merkle |
| 单次回购 | FROZEN | 0.01 BNB | SupportPool |
| 最小回购间隔 | FROZEN | 60秒 | SupportPool |
| 回购代币去向 | FROZEN | BuybackLocker | DEX接收地址 |
| 锁仓期限 | TBC | 不得写死365天 | 部署参数/Locker |
| 锁仓到期行为 | TBC | 释放、续锁或永久锁定待确认 | Locker |
| Epoch周期 | TESTNET_ASSUMPTION | 24小时，可由测试网配置冻结 | 后端任务/Distributor |
| 快照排名数量 | FROZEN | 100名 | 分红服务 |
| 黑洞方式 | TBC | `_burn`或不可恢复地址二选一 | 主网前冻结 |
| UNKNOWN成本税率 | TESTNET_ASSUMPTION | 保守按10%处理 | CostBasis/previewSell |
| 转账成本迁移 | TESTNET_ASSUMPTION | 按转出比例迁移 | CostBasisManager |

**覆盖声明：** 本表的 `35% / 30% / 20% / 15%` 覆盖旧文档和旧原型中出现的 `35% / 25% / 25% / 15%`。

## 3. 买入规则

```text
用户支付BNB/WBNB
→ TradeRouter获取DEX报价
→ 检查滑点与截止时间
→ 完成兑换
→ 4% PANGU2进入Dividend Bucket
→ 税后PANGU2进入用户钱包
→ CostBasisManager记录实际成本
```

必须提供预览：

- 输入金额。
- DEX税前报价。
- 4%协议税。
- 预计到账。
- 价格影响。
- 滑点容忍度。
- 最低到账。
- 报价区块和过期时间。

## 4. 卖出规则

### 4.1 成本比例

```text
proportionalCost = addressCostBasis × sellAmount ÷ trackedBalance
preTaxQuote = quoteTokenOutBeforeProtocolTax(sellAmount)
```

### 4.2 税率

```text
KNOWN且preTaxQuote <= proportionalCost → 4%
KNOWN且preTaxQuote > proportionalCost  → 10%
UNKNOWN → 测试网按10%
```

正式税率只能由合约 `previewSell` 返回。前端、后端和管理端不得复制公式后独立决定税率。

### 4.3 资金流

普通卖出：

```text
100%卖出数量
→ 4% Support Bucket
→ 96%进入DEX兑换
```

10%卖出状态：

```text
100%卖出数量
→ 9% Support Bucket
→ 1%销毁
→ 90%进入DEX兑换
```

## 5. 成本记录

- 官方TradeRouter买入：记录用户实际支付成本。
- 部分卖出：按卖出数量占可追踪余额比例消耗成本。
- 钱包转账：测试网按比例迁移成本，转出方减少、接收方增加。
- 无法完整追踪的历史余额或外部来源余额：标记 `UNKNOWN`。
- 后端成本数据是索引和解释数据，最终税率以合约状态为准。
- 所有舍入方向必须写入合约测试，避免利用小额转账累积差异。

## 6. 分红规则

### 6.1 三种排名必须分开

- 当前估算排名：最新链下余额估算，仅供参考。
- Epoch结算排名：指定快照区块固定。
- 可领取结果：已发布Merkle Root中的最终分配。

### 6.2 有效持币量

测试网默认排除：

- 零地址和黑洞地址。
- Pair、Router、FeeVault、SupportPool、Locker和Distributor。
- 人工冻结表列出的系统地址。
- 明确豁免且不参与分红的地址。

不得在计算代码中散落排除地址；必须从受版本控制的地址注册表读取。

### 6.3 分配公式

```text
Tier Pool = Epoch Dividend Total × Tier Percentage
User Reward = Tier Pool × User Effective Balance ÷ Tier Effective Balance Total
```

总分配不得超过Epoch分红总额；整数余数处理策略必须固定并测试。建议余数留在Distributor后续Epoch使用，不得随机分配。

## 7. 托底与回购

```text
卖出税PANGU2进入Support Bucket
→ 受限Keeper调用convertFees
→ 按单次上限兑换为BNB
→ BNB进入SupportPool
→ 任意地址在条件满足时调用buyback
→ 固定使用0.01 BNB购买PANGU2
→ 购买结果直接进入BuybackLocker
```

回购条件：

- 合约未暂停。
- 距上次成功回购至少60秒。
- SupportPool余额不少于0.01 BNB。
- DEX报价有效且满足最小输出。
- 当前无冲突执行。

管理员不得通过普通后台按钮把SupportPool资金转入运营钱包。

## 8. 锁仓基线

当前只冻结：回购所得代币必须进入Locker，且用户端不得显示“365天”或“自动续锁”。

Locker至少记录：

- 批次ID。
- 来源回购交易。
- 代币数量。
- 锁定时间。
- 解锁时间或永久标识。
- 当前状态。

锁仓期限和到期行为在主网前通过Decision Record冻结。

## 9. 合约权限基线

| 行为 | 权限 |
|---|---|
| 用户买入/卖出/领取 | 用户钱包 |
| 查询preview | 公开view |
| 触发满足条件的buyback | 公开 |
| convertFees | Keeper/受限执行角色 |
| 发布Dividend Root | Timelock或受控角色 |
| 注册Pair | Timelock |
| 修改豁免 | Timelock |
| 暂停 | Emergency角色，必须发事件 |
| 恢复 | Timelock或更高治理 |
| 提取用户资产 | 永远禁止 |
| 任意提取SupportPool | 禁止 |


---

# 技术架构与仓库基线

## 1. 总体架构

```text
用户钱包
   ↓签名/读链
DApp ────────────────┐
   │                  │
   ├─ REST API ─> Laravel API ─> PostgreSQL / Redis
   │                  ↑                 ↑
   └─ 写交易 ─> BSC合约套件 <─ Chain Worker / Job Worker
                                      ↑
Admin Web ─> Admin API ───────────────┘
                   └─ Safe / Timelock提案与只读状态
```

## 2. 架构决策

### 2.1 模块化单体

Laravel后端采用模块化单体，不拆微服务。理由：

- 盘古2需要快速交付。
- 分红、回购、索引和权限存在强一致性边界。
- 单体更容易统一事务、审计和测试。
- 后续根据真实瓶颈再拆Worker或独立服务。

### 2.2 独立Worker

以下进程与API分开运行：

- `chain-worker`：区块、交易、Receipt、Log、确认数和重组。
- `job-worker`：快照、排名、Merkle、补扫、告警和周期任务。

Worker不得直接依赖前端状态，也不得把失败只写入日志而不入库。

## 3. Laravel模块结构

```text
services/api/app/
├─ Core/
│  ├─ Auth/
│  ├─ Wallet/
│  ├─ Chain/
│  ├─ ContractRegistry/
│  ├─ Transaction/
│  ├─ Jobs/
│  ├─ RBAC/
│  ├─ Audit/
│  └─ Support/
└─ Pangu2/
   ├─ Trade/
   ├─ CostBasis/
   ├─ Dividend/
   ├─ Buyback/
   ├─ Locker/
   ├─ Treasury/
   ├─ Projection/
   ├─ Api/
   └─ Admin/
```

模块之间通过Service接口、DTO和领域事件协作。禁止跨模块直接修改对方数据库模型的内部状态。

## 4. 智能合约结构

```text
contracts/src/
├─ Pangu2Token.sol
├─ Pangu2TradeRouter.sol
├─ CostBasisManager.sol
├─ FeeVault.sol
├─ SupportPool.sol
├─ BuybackLocker.sol
├─ DividendDistributor.sol
├─ GovernanceAdapter.sol
├─ interfaces/
├─ libraries/
└─ mocks/
```

### 4.1 合约职责

| 合约 | 单一职责 |
|---|---|
| Pangu2Token | ERC20、Pair识别、税费扣取、销毁 |
| Pangu2TradeRouter | 官方买卖、preview、滑点、DEX调用 |
| CostBasisManager | 成本、可追踪余额、转账迁移、UNKNOWN |
| FeeVault | Dividend/Support Bucket隔离与转换入口 |
| SupportPool | 持有BNB并固定0.01 BNB回购 |
| BuybackLocker | 接收和记录回购代币锁仓批次 |
| DividendDistributor | Epoch Root、Proof验证、领取和防重领 |
| GovernanceAdapter | Safe/Timelock受控调用边界 |

合约之间不得形成可重入的循环调用。所有外部DEX调用必须使用重入保护、截止时间和最小输出。

## 5. 前端结构

```text
apps/dapp/src/
├─ app/
├─ pages/
├─ features/
│  ├─ wallet/
│  ├─ trade/
│  ├─ dividend/
│  ├─ buyback/
│  └─ portfolio/
├─ components/
├─ services/
├─ stores/
├─ types/
└─ config/
```

```text
apps/admin/src/
├─ pages/
├─ features/
│  ├─ dashboard/
│  ├─ contracts/
│  ├─ transactions/
│  ├─ dividends/
│  ├─ buybacks/
│  ├─ jobs/
│  ├─ security/
│  └─ audit/
├─ components/
├─ services/
├─ stores/
└─ types/
```

前端业务规则不得复制合约公式。UI使用合约预览和API聚合结果。

## 6. 低成本平台预留

现在只做以下预留：

- 公共表带 `project_id`、`environment`、`chain_id`。
- API路径包含 `/projects/pangu2/`。
- 合约地址和ABI通过注册表读取。
- Pangu2规则集中在Pangu2模块。
- 原始链上表与业务投影表分离。
- 共享交易状态、错误码和数据新鲜度。

现在明确不做：

- `ProjectModule`动态插件加载。
- 多项目后台切换器。
- 动态表结构和动态经济模型编辑器。
- 多链RPC抽象层的大规模实现。
- 服务网格、消息总线或分布式事务。

## 7. 配置基线

配置分层：

```text
代码默认值（非敏感）
→ 环境配置
→ 合约注册表
→ 链上真实状态
```

规则：

- 私钥、Token、RPC密钥不得提交仓库。
- 合约地址不得散落写在前端源代码。
- 税率和资金路径不得只依赖环境变量。
- 测试网和主网配置必须物理分离。
- 配置变更必须记录版本和审计。

## 8. 依赖和版本约束

- `composer.lock`、`pnpm-lock.yaml`和Foundry依赖提交仓库。
- CI使用锁文件安装，禁止自动漂移。
- ABI包使用语义版本；合约ABI破坏性变化必须升级主版本。
- API Schema必须生成版本和变更记录。
- 数据库迁移文件一经进入共享分支不得改写，只能追加修正迁移。

## 9. 非功能目标

| 指标 | 测试网基线 |
|---|---|
| API P95 | 常规读接口目标 < 500ms，不含RPC实时调用 |
| 数据新鲜度 | 正常状态落后不超过配置确认数+2个区块 |
| Worker恢复 | 重启后从持久化Cursor继续 |
| 幂等 | 同一Log重复处理不产生重复业务记录 |
| 重组 | 能回滚未最终确认投影并重新应用 |
| 可观测 | 关键任务、RPC、同步高度和失败率有指标 |
| 安全 | 所有管理写操作鉴权、授权、审计 |


---

# 接口、数据、事件与状态基线

## 1. API命名

用户API：

```text
/api/v1/projects/pangu2/...
```

管理API：

```text
/admin-api/v1/projects/pangu2/...
```

统一响应：

```json
{
  "success": true,
  "data": {},
  "meta": {
    "project_id": "pangu2",
    "environment": "bsc_testnet",
    "chain_id": 97,
    "data_status": "LIVE",
    "block_number": "12345678",
    "generated_at": "2026-08-01T01:00:00+08:00"
  },
  "error": null
}
```

## 2. 用户API基线

| Method | Path | 用途 |
|---|---|---|
| GET | `/config` | 网络、合约、功能开关和展示配置 |
| GET | `/status` | 系统、同步和数据新鲜度 |
| GET | `/contracts` | 合约地址、ABI版本和浏览器链接 |
| GET | `/market/quote` | 参考报价和来源信息 |
| POST | `/trade/preview-buy` | 买入预览聚合 |
| POST | `/trade/preview-sell` | 调用/模拟合约previewSell，不自行判税 |
| GET | `/wallets/{address}/summary` | 余额、排名、领取和交易摘要 |
| GET | `/wallets/{address}/transactions` | 业务交易记录 |
| GET | `/dividends/current` | 当前Epoch和估算信息 |
| GET | `/dividends/epochs/{epoch}` | 快照、分配和Root状态 |
| GET | `/dividends/epochs/{epoch}/proof/{address}` | Merkle proof |
| GET | `/buybacks` | 回购记录 |
| GET | `/support-pool` | 托底池余额和执行条件 |
| GET | `/locker` | 锁仓汇总和批次 |

写链交易由用户钱包直接提交。后端可以提供calldata/预览，但不得代签。

## 3. 管理API基线

| Method | Path | 权限/用途 |
|---|---|---|
| GET | `/dashboard` | 运营总览 |
| GET | `/chain/sync` | 同步高度、RPC、延迟 |
| POST | `/chain/rescan` | 受限补扫，需审计 |
| GET | `/contracts` | 合约注册和链上状态 |
| GET | `/transactions` | 交易查询 |
| GET | `/fee-vault` | 分红/托底Bucket |
| POST | `/fee-vault/convert-proposal` | 生成受控执行或Safe提案 |
| GET | `/buybacks` | 回购记录和条件 |
| GET | `/dividend-epochs` | Epoch列表 |
| POST | `/dividend-epochs` | 创建Epoch草稿 |
| POST | `/dividend-epochs/{id}/snapshot` | 固定快照 |
| POST | `/dividend-epochs/{id}/calculate` | 计算排名与分配 |
| POST | `/dividend-epochs/{id}/generate-root` | 生成Root和proof文件 |
| POST | `/dividend-epochs/{id}/publish-proposal` | 生成链上发布提案 |
| GET | `/jobs` | 任务运行和失败 |
| POST | `/jobs/{id}/retry` | 幂等重试 |
| GET | `/alerts` | 系统告警 |
| GET | `/audit-logs` | 审计日志 |
| GET/POST | `/roles` | RBAC管理，最高权限受限 |

## 4. 数据库基线

### 4.1 公共表

```text
projects
project_environments
chains
rpc_endpoints
contract_registry
contract_abi_versions
users
user_wallets
wallet_nonces
admin_users
roles
permissions
role_assignments
chain_blocks
chain_transactions
chain_receipts
chain_event_logs
chain_token_transfers
chain_sync_cursors
transactions
transaction_attempts
jobs
job_runs
job_failures
outbox_events
system_alerts
audit_logs
configuration_versions
```

### 4.2 盘古2业务表

```text
pangu2_trades
pangu2_cost_basis_positions
pangu2_cost_basis_movements
pangu2_fee_bucket_snapshots
pangu2_buyback_cycles
pangu2_buyback_executions
pangu2_locker_batches
pangu2_dividend_epochs
pangu2_dividend_snapshot_balances
pangu2_dividend_rankings
pangu2_dividend_allocations
pangu2_dividend_claims
pangu2_contract_state_snapshots
```

### 4.3 数据类型

- 链ID：bigint或integer。
- 区块号、Nonce：bigint/string DTO。
- 地址：规范化小写存储，同时保留checksum展示值可选。
- 金额：`numeric(78,0)`或十进制整数字符串。
- 哈希：固定长度字符串并建唯一索引。
- 时间：UTC存储，API按ISO 8601输出。
- 唯一事件键：`chain_id + tx_hash + log_index`。

## 5. 链上事件基线

最低事件集合：

```text
PairUpdated(pair, enabled)
ExemptionUpdated(account, flags)
TokensPurchased(buyer, amountIn, grossTokens, taxTokens, netTokens)
TokensSold(seller, tokenIn, taxBps, supportTokens, burnTokens, swapTokens, amountOut)
CostBasisIncreased(account, costAmount, trackedAmount)
CostBasisConsumed(account, costAmount, trackedAmount)
CostBasisTransferred(from, to, costAmount, tokenAmount)
FeeBucketCredited(bucket, tokenAmount)
FeesConverted(bucket, tokenAmount, bnbAmount)
BuybackExecuted(trigger, bnbAmount, tokenAmount, locker)
LockBatchCreated(batchId, tokenAmount, unlockAt)
DividendRootPublished(epoch, snapshotBlock, totalAmount, merkleRoot)
DividendClaimed(epoch, account, amount)
Paused(account)
Unpaused(account)
```

事件字段一经前后端联调冻结，不得无版本地改名或改变含义。

## 6. 内部事件基线

```text
chain.block.indexed
chain.event.indexed
chain.reorg.detected
transaction.submitted
transaction.confirmed
transaction.failed
pangu2.trade.projected
pangu2.buyback.available
pangu2.buyback.executed
pangu2.dividend.snapshot.completed
pangu2.dividend.calculation.completed
pangu2.dividend.root.generated
pangu2.dividend.root.published
system.rpc.degraded
system.indexer.stale
security.contract.paused
```

内部事件写入Outbox，与业务事务同提交，再由Worker投递，避免数据库成功但通知丢失。

## 7. 状态机

### 7.1 用户交易状态

```text
IDLE
WALLET_NOT_CONNECTED
WRONG_NETWORK
QUOTE_LOADING
QUOTE_READY
QUOTE_EXPIRED
APPROVAL_REQUIRED
APPROVAL_PENDING
APPROVAL_CONFIRMED
SIGNATURE_PENDING
USER_REJECTED
SUBMITTED
PENDING
CONFIRMED
FAILED
REPLACED
DROPPED
REORG_RECHECK
DATA_STALE
```

### 7.2 Epoch状态

```text
DRAFT
SNAPSHOT_PENDING
SNAPSHOT_FIXED
CALCULATING
CALCULATED
ROOT_GENERATED
PUBLISH_PROPOSED
ROOT_PUBLISHED
CLAIM_OPEN
CLAIM_CLOSED
CANCELLED
FAILED
```

状态只能按允许路径迁移；任何回退和重算必须保留版本和审计。

### 7.3 Worker任务状态

```text
QUEUED
RUNNING
SUCCEEDED
FAILED_RETRYABLE
FAILED_FINAL
CANCELLED
```

## 8. 数据状态

```text
MOCK_DATA
SYNCING
LIVE
STALE
DEGRADED
UNAVAILABLE
```

DApp和管理端必须显示数据状态；不得把STALE数据标为实时。

## 9. 错误码基线

| 错误码 | 含义 |
|---|---|
| `WALLET_NOT_CONNECTED` | 钱包未连接 |
| `WRONG_NETWORK` | 网络不正确 |
| `QUOTE_EXPIRED` | 报价过期 |
| `SLIPPAGE_EXCEEDED` | 滑点超限 |
| `INSUFFICIENT_BALANCE` | 资产余额不足 |
| `INSUFFICIENT_GAS` | Gas不足 |
| `APPROVAL_REQUIRED` | Allowance不足 |
| `USER_REJECTED` | 用户拒签 |
| `CONTRACT_PAUSED` | 合约暂停 |
| `BUYBACK_NOT_READY` | 间隔或余额条件不满足 |
| `DIVIDEND_NOT_PUBLISHED` | Root未发布 |
| `ALREADY_CLAIMED` | 已领取 |
| `INVALID_PROOF` | Proof无效 |
| `CHAIN_DATA_STALE` | 链上数据过期 |
| `RPC_UNAVAILABLE` | RPC不可用 |
| `REORG_RECHECK` | 重组后重新确认 |
| `PERMISSION_DENIED` | 管理权限不足 |
| `IDEMPOTENCY_CONFLICT` | 幂等键冲突 |

错误响应不得泄露私钥、RPC Token、内部堆栈或敏感配置。


---

# 测试、安全与验收基线

## 1. 测试原则

```text
真实入口/合约公开函数
→ 真实Service/Adapter
→ 必要集成测试
→ 辅助函数测试
→ Mock
```

禁止：

- 仅断言函数被调用。
- 用Mock绕过真实资金路径。
- `.skip`、宽松断言或吞掉异常。
- 用源码字符串搜索代替行为测试。
- 修改Workflow让失败检查不阻塞。
- 将基线已有失败误报为本任务通过。

## 2. 合约测试矩阵

### 2.1 单元测试

- 总量一次性铸造且无公开增发。
- Pair识别、买入4%、普通卖出4%、盈利状态10%。
- 10%状态严格满足9%托底、1%销毁、90%兑换。
- CostBasis增加、消费、转账迁移和UNKNOWN。
- FeeVault两个Bucket严格隔离。
- convertFees权限、上限、滑点和接收地址。
- SupportPool固定0.01 BNB和60秒间隔。
- Locker只能接收预期来源并记录批次。
- Root发布、Proof验证、防重领和总额上限。
- Pause、Unpause和Timelock权限。

### 2.2 Fuzz测试

- 任意有效买入金额的税费守恒。
- 任意卖出金额的税费分解守恒。
- 部分卖出后的成本不为负、不超原成本。
- 转账迁移前后总成本守恒。
- 不同小数和舍入边界不产生额外代币。
- Merkle领取总额不超过Epoch总额。

### 2.3 Invariant

```text
总供应量 = 所有账户余额总和
Dividend Bucket与Support Bucket不得混用
SupportPool回购单次BNB永远等于0.01 BNB（条件满足时）
任何用户累计领取不得超过分配
任何Epoch总领取不得超过Epoch总额
CostBasis不得为负
管理员不能转走用户余额
```

### 2.4 攻击测试

- 重入。
- 闪电贷价格操纵和报价边界。
- Sandwich/滑点和过期报价。
- 恶意Token/DEX回调。
- 权限提升。
- 重复领取。
- 通过转账规避成本。
- 小额尘埃攻击和舍入套利。
- DoS排名或超大数组。

## 3. 后端和Worker测试

- 签名Nonce一次性使用和过期。
- 地址规范化。
- Event Log幂等。
- Worker重启恢复Cursor。
- RPC故障切换和退避。
- 链重组回滚与重放。
- 交易确认、替换、丢弃和失败。
- Snapshot固定区块后不可静默改变。
- 排名排除地址正确。
- 35/30/20/15四档金额正确。
- 整数余数处理稳定。
- Merkle文件与数据库分配一致。
- Outbox不丢事件。
- 任务重试不重复写入。
- RBAC和项目范围隔离。
- 管理写操作全部有审计。

## 4. DApp测试

必须覆盖：

- 未连接钱包。
- 错误网络和切链失败。
- 买入MAX预留Gas。
- 报价加载、过期和刷新。
- Allowance不足的两笔交易流程。
- 用户拒签。
- 普通卖出4%。
- 盈利状态卖出10%。
- pending、confirmed、failed、replaced、dropped和reorg。
- 领取后余额、可领取和记录同步变化。
- 当前估算排名与Epoch排名分离。
- 数据STALE和RPC不可用。
- 移动端关键分辨率和44px点击区域。

## 5. 管理端测试

- 登录、会话过期和权限菜单。
- 不同角色访问控制。
- 危险操作二次确认。
- 创建Epoch、快照、计算、生成Root和发布提案。
- 已发布Epoch不能无审计修改。
- 补扫和任务重试幂等。
- Safe/Timelock状态只读同步。
- SupportPool不能通过普通接口提现。
- 所有写操作产生审计记录。

## 6. 安全硬规则

1. 私钥和助记词永不进入仓库、日志或数据库。
2. 后端不得托管用户签名。
3. 管理员不能直接改变用户成本、余额或领取结果。
4. SupportPool、FeeVault和Distributor资金必须合约隔离。
5. 权限变更、Pair注册、豁免和Root发布必须发链上事件。
6. 生产Safe签名人和Timelock参数不在测试网文档中伪造确定值。
7. API输入全部验证，地址、金额、chain_id和幂等键不可隐式转换。
8. 日志脱敏，不记录Authorization、私钥、完整RPC密钥和签名材料。
9. 后台危险操作必须显式显示目标网络、合约、金额和calldata摘要。
10. 主网前必须独立安全审计和修复验证。

## 7. Required Checks

每个PR至少要求：

```text
contracts-format
contracts-build
contracts-unit
contracts-fuzz-smoke
backend-lint
backend-test
worker-lint
worker-test
dapp-lint
dapp-unit
dapp-build
admin-lint
admin-unit
admin-build
schema-drift-check
forbidden-path-check
```

涉及相应模块的检查必须绑定当前Head SHA。未修改模块可按可信路径过滤，但不得通过条件配置绕过应运行的测试。

## 8. 阶段验收

### 8.1 合约阶段

- 所有合约可编译、部署和初始化。
- FROZEN参数与基线一致。
- Fuzz/Invariant无阻塞失败。
- ABI、事件和部署清单交付。
- 权限图和资金流图通过审核。

### 8.2 后端/Worker阶段

- 从部署区块可重建链上业务数据。
- 重复同步不产生重复记录。
- 重组、RPC故障和重启可恢复。
- API Schema和数据库迁移冻结。
- 排名和Merkle可复现。

### 8.3 前端阶段

- 真实测试网钱包和合约交互通过。
- 不存在前端自行判税。
- 完整状态机和错误恢复通过。
- 模拟数据与真实数据明确区分。

### 8.4 管理端阶段

- 权限、审计、任务和Epoch全流程通过。
- 管理端不具备未授权资金出口。
- Safe/Timelock操作以提案和状态呈现。

### 8.5 测试网Closeout

- 全链路闭环通过。
- Blocking Findings全部关闭。
- Required Checks全部通过。
- Final Head SHA固定。
- 测试证据、已知风险、部署地址和回滚说明齐全。

## 9. 主网发布Gate

主网保持 `NO-GO`，直至：

- 所有TBC参数签署冻结。
- 独立安全审计完成并复验。
- 主网Safe、Timelock、签名人和权限确认。
- 流动性、初始分配和迁移计划批准。
- 监控、告警、应急暂停和事件响应演练完成。
- 发布Source SHA、Artifact Digest和部署脚本固定。
- 人工项目负责人明确批准部署。


---

# 阶段、任务与交付基线

## 1. 总体阶段

```text
PB-S0 基线冻结
PB-S1 合约实现
PB-S2 后端Core与链上Worker
PB-S3 盘古2业务后端
PB-S4 用户端DApp
PB-S5 运营管理端
PB-S6 测试网集成与Closeout
PB-S7 平台抽取（盘古2完成后，Deferred）
```

## 2. PB-S0 基线冻结

**目标：** 形成唯一可执行基线。

必须完成：

- 参数冻结矩阵签署。
- 合约清单、职责、接口和事件草案。
- 数据库、API、状态机和错误码基线。
- 仓库结构、技术栈和Required Checks。
- 原型修复：35/30/20/15、无365天、税率由合约返回。

关闭条件：

- 所有P0冲突消除。
- TBC项有测试网假设或明确阻塞。
- Spec SHA与Ruleset SHA固定。

## 3. PB-S1 合约实现

建议任务：

| Task ID | 内容 | Allowed Paths |
|---|---|---|
| P2-C01 | Token、Pair和基础税费 | `contracts/src/Pangu2Token.sol`、对应测试 |
| P2-C02 | TradeRouter与preview | Router、接口、Mock、测试 |
| P2-C03 | CostBasisManager | 成本合约和测试 |
| P2-C04 | FeeVault与转换 | Vault、DEX Adapter、测试 |
| P2-C05 | SupportPool与回购 | Pool、测试 |
| P2-C06 | Locker | Locker、测试 |
| P2-C07 | DividendDistributor | Distributor、Merkle测试 |
| P2-C08 | Governance与部署脚本 | Adapter、script、部署验证 |
| P2-C09 | 全套Invariant与集成测试 | `contracts/test/` |

Forbidden：前端、后端业务实现、主网部署和生产密钥。

## 4. PB-S2 后端Core与链上Worker

建议任务：

| Task ID | 内容 |
|---|---|
| P2-B01 | Laravel骨架、项目/环境/链配置 |
| P2-B02 | 钱包Nonce和签名认证 |
| P2-B03 | 合约注册、ABI版本和地址服务 |
| P2-B04 | RBAC、管理员会话和审计 |
| P2-W01 | 区块、交易、Receipt和Log同步 |
| P2-W02 | Cursor、确认数、RPC容灾和重组 |
| P2-B05 | 统一交易状态、API响应和错误码 |
| P2-B06 | 队列、幂等、Outbox和任务监控 |

此阶段可以和PB-S1并行，但合约事件解析器在ABI冻结后才能关闭。

## 5. PB-S3 盘古2业务后端

建议任务：

| Task ID | 内容 |
|---|---|
| P2-D01 | 买卖、税费和成本业务投影 |
| P2-D02 | FeeVault、SupportPool和回购投影 |
| P2-D03 | Locker批次与统计 |
| P2-D04 | 持币快照和系统地址排除 |
| P2-D05 | 前100名与35/30/20/15分配 |
| P2-D06 | Merkle生成、文件校验和Proof API |
| P2-D07 | 用户资产摘要和交易查询API |
| P2-D08 | 管理端Epoch、任务和告警API |

关闭条件：相同快照输入必须生成完全一致的排名、分配和Root。

## 6. PB-S4 用户端DApp

建议任务：

| Task ID | 内容 |
|---|---|
| P2-F01 | 应用骨架、钱包、网络和配置 |
| P2-F02 | 首页与资产摘要 |
| P2-F03 | 买入预览和交易 |
| P2-F04 | 卖出preview、授权和交易 |
| P2-F05 | 分红排名、Epoch和领取 |
| P2-F06 | 托底、回购与Locker展示 |
| P2-F07 | 我的、交易历史和状态恢复 |
| P2-F08 | E2E、移动端和错误状态验收 |

唯一原型维护对象：`pangu2_mobile_dapp_v4_model_aligned.html`。正式实现以基线和ABI为准，原型不得覆盖链上规则。

## 7. PB-S5 运营管理端

建议任务：

| Task ID | 内容 |
|---|---|
| P2-A01 | 登录、RBAC、布局和导航 |
| P2-A02 | 运营总览与系统状态 |
| P2-A03 | 合约注册和链上同步 |
| P2-A04 | 交易、税费和成本查询 |
| P2-A05 | SupportPool、回购和Locker |
| P2-A06 | Epoch、排名、分配和Root |
| P2-A07 | Job、告警、审计和权限 |
| P2-A08 | Safe/Timelock提案和状态展示 |

禁止提供管理员直接修改用户资产、成本、排名分配或任意提取托底资金的入口。

## 8. PB-S6 测试网集成

任务包：

- 部署和初始化测试网合约。
- 固定地址清单、ABI版本和部署区块。
- Worker从部署区块同步。
- DApp连接真实测试网合约。
- 管理端连接真实管理API。
- 执行买入、两类卖出、转换、回购、锁仓、Epoch、Root和领取。
- 执行重组模拟、RPC故障、任务重试和数据重建。
- 完成Closeout审核。

## 9. 并行关系

```text
PB-S0
  ├─> PB-S1 合约
  └─> PB-S2 后端骨架/Worker
          ↓ ABI与事件冻结
       PB-S3 业务后端
          ├─> PB-S4 DApp
          └─> PB-S5 Admin
                 ↓
              PB-S6 集成
```

DApp可先实现钱包、布局和Mock状态，但交易关闭条件必须等待真实ABI和测试网。

## 10. 每个任务的标准输入

```text
Project ID
Stage ID
Task ID
Prompt Version
Repository
Base Branch / Base SHA
Spec SHA / Ruleset SHA
Goal
Allowed Paths
Forbidden Paths
Requirements
Required Tests
Required Checks
Closure Conditions
Dependencies
```

## 11. 每个任务的标准交付

- 修改文件与用途。
- 数据库迁移或ABI/API变更说明。
- 本地测试命令、退出状态和结果。
- GitHub Actions与当前Head SHA。
- 已知风险和未完成项。
- 审核Agent可复制提示词。

## 12. PB-S7 平台抽取

状态：`DEFERRED`。

只有PB-S6关闭后才能启动。先接入第二个最小项目验证复用，再抽取ProjectModule、ContractAdapter和多项目后台，禁止在盘古2交付前提前扩大范围。


---

# 开发启动检查清单

## A. 项目级Start Gate

- [ ] Project ID = `PANGU2`
- [ ] Baseline ID = `PANGU2-DEV-BASELINE-V1.0`
- [ ] 开发策略 = `PANGU2_FIRST_PLATFORM_READY`
- [ ] 目标环境 = `BSC_TESTNET`
- [ ] 主网状态 = `NO-GO`
- [ ] Repository、Base Branch和Base SHA已填写
- [ ] Spec SHA和Ruleset SHA已固定
- [ ] 角色规则文件已加载
- [ ] Automatic Merge = FORBIDDEN
- [ ] Automatic Deployment = FORBIDDEN

## B. 业务参数Gate

- [ ] 买入税4%
- [ ] 普通卖出4%
- [ ] 10%卖出为9%托底+1%销毁
- [ ] 额外6%整笔计税仅标记TESTNET_ASSUMPTION
- [ ] 分红档位为35/30/20/15
- [ ] 旧版35/25/25/15已标记失效
- [ ] 每次回购0.01 BNB
- [ ] 最小间隔60秒
- [ ] 回购代币进入Locker
- [ ] 未写死365天
- [ ] previewSell是税率唯一来源
- [ ] UNKNOWN成本测试网策略已确认

## C. 合约任务Gate

- [ ] 合约职责和依赖图已确认
- [ ] 接口和事件草案已固定
- [ ] DEX Pair/Router测试地址已确认
- [ ] 权限角色和初始化顺序已确认
- [ ] 单元、Fuzz、Invariant测试要求已写入Task Spec
- [ ] 禁止访问生产私钥和主网资金

## D. 后端/Worker任务Gate

- [ ] 数据库表和唯一键已确认
- [ ] 金额不使用浮点数
- [ ] 部署区块和确认数可配置
- [ ] 重组处理和Cursor持久化已纳入范围
- [ ] 幂等键和Outbox已定义
- [ ] API Schema与错误码已固定
- [ ] RBAC和审计要求已写入任务

## E. DApp任务Gate

- [ ] 唯一原型文件已确认
- [ ] ABI、合约地址和chain_id可用
- [ ] 买入/卖出预览字段固定
- [ ] Allowance两阶段流程固定
- [ ] 数据状态和交易状态机固定
- [ ] 当前排名/Epoch排名/可领取结果分开
- [ ] MAX预留Gas
- [ ] 不显示固定365天
- [ ] 不允许用户选择4%或10%

## F. Admin任务Gate

- [ ] 页面范围固定
- [ ] 每个写操作权限固定
- [ ] Safe/Timelock操作与普通后台操作分开
- [ ] 禁止修改用户资产和成本
- [ ] 禁止普通提现SupportPool
- [ ] 危险操作有二次确认和审计

## G. Review Gate

- [ ] PR Number已提供
- [ ] Merge Base SHA已提供
- [ ] Head SHA已固定
- [ ] Required Checks绑定当前Head SHA
- [ ] Workflow、测试命令和锁文件Diff已检查
- [ ] Forbidden Paths无修改
- [ ] Blocking Findings全部在当前SHA验证关闭

## H. 测试网Closeout

- [ ] 部署地址和部署区块记录齐全
- [ ] 完整链路真实执行通过
- [ ] DApp、管理端、数据库和链上数据一致
- [ ] 重组、RPC故障和重启恢复验证
- [ ] 测试证据归档
- [ ] 已知风险与TBC列表更新
- [ ] Review Verdict = APPROVED
- [ ] Lifecycle Recommendation = MERGE_READY
- [ ] 人工项目负责人决定是否合并
- [ ] 仍未进入主网部署
