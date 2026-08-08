# BingGoPlus — Coding Rules

## 通用
- BSC_MAINNET deployment NO-GO, all scripts revert on chain 56
- No auto merge/auto push/auto deploy
- .env never committed; keys never logged
- All admin-api write routes MUST have `['auth:web', 'rbac:xxx']`
- OpenTrading must NEVER be called by CI, deployment scripts, or startup scripts

## Solidity (contracts-v2/)
- OpenZeppelin AccessControl + Pausable + ReentrancyGuard
- All amounts uint256 wei/BigInt, no float
- nonReentrant on all state-changing external functions
- Checks-Effects-Interactions pattern
- Stage 1→2→3→4→OpenTrading strict order
- Bootstrap Factory must match Deploy Factory
- `forge test --no-match-path "*/fork/*"` for unit tests

### 合约修复阶段规则 (S0-S9)
- 一次只执行一个阶段，不得提前做下一阶段
- 修改代码前必须先提交只读审核 → 校对确认 → 才能实现
- 实现 Agent 不得自行签发独立批准
- P0/P1/P2 不得用"后续再处理"关闭
- P3 只有用户书面批准 ACCEPTED_DEVIATION 才能不改代码
- 禁止改变冻结税率、供应量、Launch 时间、回购金额、冷却、Claim 窗口

## Backend (Laravel)
- ApiEnvelope::success() / error() format
- BC Math for amounts, no PHP float
- strict_types=1
- RBAC via RbacMatrix + auth:web guard (must coexist)
- CSRF on all POST endpoints — unless explicitly justified
- Job Retry: Idempotency-Key + RetryTokenJob
- ChainOperatorService: private key from config only, never in code/response/log

## 文档与规划修订（Freeze / SQL / OpenAPI / State / Governance）
- 权威顺序遵循 `docs/current/go-backend-v2/README.md`；低权威 Markdown 不得覆盖 SQL/OpenAPI/YAML/已部署事实
- 机器规范与说明文档必须同 revision；提审包须含 SUBMISSION_MANIFEST（path/size/sha256）
- Finding 作者侧仅 `FIX_READY / INDEPENDENT_RETEST_PENDING`；不得自标独立审核 `CLOSED`
- 团队/推荐/佣金保持 `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`
- Raw Event 禁止重新引入物理 `PROJECTED`；Dividend Artifact 禁止读 current 表
- 本轮默认不新增依赖；不改 Solidity/已部署地址；Mainnet NO-GO

## Go Backend V2（设计冻结完成，代码未开始）

### G0 阶段约束（当前）
- 不得创建 `backend-go/` 业务代码
- 不得下载未经批准的 Go 依赖
- 不得在无 PostgreSQL 16+ 实例时声称 Migration 通过
- 不得自行寻找公共 RPC 冒充批准输入

### G1 阶段约束（仅 FROZEN_FOR_DEVELOPMENT = YES 后允许；Responsible Owner Freeze 或 Design Freeze 单独完成不能授权 G1）
- 单一 Go Module，模块化单体
- 金额: DB `NUMERIC(78,0)`, Go `big.Int`, JSON 十进制整数字符串
- 前端类型只从 OpenAPI 生成
- `chain_id=56` 永久拒绝启动写进程
- 单写者原则: 每个环境只有一个 Indexer Writer
- G1 仅允许：`cmd/` skeleton、config bootstrap、health endpoint、DB connection bootstrap、generated-code placeholders
- G1 严禁：Trade/Dividend/Governance 业务逻辑、Indexer 扫描、Projector 投影、Signer 签名、链上写入

### Go V2 数据库角色隔离
- 运行进程以同名 LOGIN Role 直接连接（`bgp_api`、`bgp_indexer` 等），`current_user` exact role model
- 不得依赖 INHERIT Group Role 或 `SET ROLE`
- `bgp_migrator` 不与任何运行角色共享或继承
- 角色密码/Secret 由平台托管，不在仓库内

### Go V2 依赖准入
- 所有依赖当前状态：`NO_DOWNLOAD_AUTHORIZED`
- 必须完成 Decision Record（license、POC、benchmark、TCO、SBOM）并获 `APPROVE_DOWNLOAD` 后才能加入 `go.mod`
- 特别注意 go-ethereum（LGPL 风险）和 River（MPL-2.0 文件级义务）
- 禁止 `go get ...@latest`、浮动 branch、pseudo-version 指向未批准 commit

## Chain Worker
- All config from config.ts (single source)
- BigInt → decimal string before JSON
- DEPLOYMENT_BLOCK must match actual deploy block
- 6 event streams must be defined centrally, used by scanner/cursor/health/reorg

## Frontend (DApp)
- TypeScript strict mode, types from @pangu2/api-types
- DApp V7.1 3-page architecture
- CSS tokens from packages/ui/tokens.css — all variables defined there
- Contract addresses from deployed.ts — MUST match deployment broadcast
- All `<button>` elements MUST have `type="button"`
- Trading-disabled: no countdown, no auto-activate, Admin manual control

## Admin
- CSRF before login; write ops via adminFetch; 419 retried once
- Frontend field names MUST match backend response field names

## 信息来源
- contracts-v2/src/*.sol, contracts-v2/broadcast/
- backend/routes/web.php, backend/app/Modules/
- apps/dapp/src/views/, apps/dapp/src/router/index.ts
- docs/current/go-backend-v2/contracts/remediation/README.md
- docs/current/go-backend-v2/runtime-gate/05_GO_BUILD_STAGE_DECISION.md
- docs/current/go-backend-v2/07_FRAMEWORK_AND_DEPENDENCIES.md
- packages/ui/tokens.css
