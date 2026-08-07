# PANGU2 — Coding Rules

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

## 文档与规划修订（文档优化项目）
- 权威顺序遵循 `docs/current/go-backend-v2/README.md`；低权威 Markdown 不得覆盖 SQL/OpenAPI/YAML/已部署事实
- 机器规范与说明文档必须同 revision；提审包须含 SUBMISSION_MANIFEST（path/size/sha256）
- Finding 作者侧仅 `FIX_READY / INDEPENDENT_RETEST_PENDING`；不得自标独立审核 `CLOSED`
- 团队/推荐/佣金保持 `OUT_OF_SCOPE / ROADMAP_NOT_APPROVED`
- Raw Event 禁止重新引入物理 `PROJECTED`；Dividend Artifact 禁止读 current 表
- 本轮默认不新增依赖；不改 Solidity/已部署地址；Mainnet NO-GO

## Go Backend V2 (冻结中，未实施)
- 单一 Go Module，模块化单体
- 金额: DB `NUMERIC(78,0)`, Go `big.Int`, JSON 十进制整数字符串
- 前端类型只从 OpenAPI 生成
- `chain_id=56` 永久拒绝启动写进程
- 单写者原则: 每个环境只有一个 Indexer Writer

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
- packages/ui/tokens.css
