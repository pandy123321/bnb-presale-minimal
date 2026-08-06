# PANGU2 V2 部署文档

版本: V2 (PancakeSwap V2 AMM) | 支持链: BSC Testnet (97) + BSC Mainnet (56) | 更新: 2026-08-04

## 前置条件

| 工具 | 安装 |
|---|---|
| Foundry (forge + cast) | `irm https://getfoundry.sh \| iex` |
| MetaMask | https://metamask.io |
| Node.js 22+ | https://nodejs.org |

验证: `forge --version` / `cast --version`

---

## 1. BSC 网络配置

MetaMask → 设置 → 网络 → 添加网络:

| 参数 | Testnet | Mainnet |
|---|---|---|
| 名称 | BSC Testnet | BSC Mainnet |
| RPC | https://data-seed-prebsc-1-s1.binance.org:8545 | https://bsc-dataseed1.binance.org |
| Chain ID | 97 | 56 |
| 符号 | BNB | BNB |
| 浏览器 | https://testnet.bscscan.com | https://bscscan.com |

---

## 2. 领测试币 (Testnet)

打开 https://testnet.bscscan.com/faucet → 输入钱包地址 → 领取 0.3 BNB。

---

## 3. 导出私钥

MetaMask → 账户详情 → 导出私钥 → 复制

**绝不分享、截图或提交到 Git。**

---

## 4. 配置 .env

```powershell
cd E:\github\bnb\bnb-presale-minimal\contracts-v2
copy .env.example .env
notepad .env
```

填写:

| 字段 | 说明 | 示例值 |
|---|---|---|
| CHAIN_ID | 97=Testnet, 56=Mainnet | 97 |
| RPC_URL | 链 RPC 端点 | https://data-seed-prebsc-1-s1.binance.org:8545 |
| GOVERNANCE_ADDRESS | 治理地址 | 0x你的地址 |
| EMERGENCY_ADDRESS | 紧急暂停地址 | 0x你的地址 |
| KEEPER_ADDRESS | 税费兑换触发 | 0x你的地址 |
| RELEASE_RECIPIENT_ADDRESS | 锁仓释放接收 | 0x你的地址 |
| INITIAL_HOLDER_ADDRESS | 初始代币接收 | 0x你的地址 |
| ROOT_PUBLISHER_ADDRESS | 分红 Root 发布 | 0x你的地址 |
| LIQUIDITY_PROVIDER_ADDRESS | LP 提供者 | 0x你的地址 |
| DEPLOYER_PRIVATE_KEY | 部署私钥 | 你的私钥 |
| LIQUIDITY_PROVIDER_PRIVATE_KEY | LP 私钥 | 你的私钥 |
| MIN_TOKEN_RESERVE | Oracle 最小 Token | 100000000000000000 |
| MIN_WBNB_RESERVE | Oracle 最小 WBNB | 10000000000000000 |
| INITIAL_LIQUIDITY_TOKENS | 初始 Token 注入 | 1000000000000000000000 |
| INITIAL_LIQUIDITY_BNB | 初始 BNB 注入 | 1000000000000000000 |
| MIN_LIQUIDITY_TOKENS | 最小 Token 滑点 | 900000000000000000000 |
| MIN_LIQUIDITY_BNB | 最小 BNB 滑点 | 900000000000000000 |
| LP_RECIPIENT | LP Token 接收 | 0x你的地址 |
| ORACLE_TEST_AMOUNT | Oracle 测试额 | 1000000000000000000 |

**测试网可填同一个地址给所有角色。主网必须分离。**

---

## 5. 部署合约

```powershell
.\deploy-and-test.ps1
```

输出示例:

```
=== PANGU2 V2 Deployed (2026-08-05) ===
Token: 0xaf2bD8bF6b1a0E6B94c2b10150F9184D142eef1C
TradeRouter: 0x16f5418A4A2D7D8675228fe2230A565e595954fe
DividendDistributor: 0x6265b64de9a3f7198E40082ea82BAcCAfD1E14CB
SupportPool: 0x91F8cEe7E08E5DC5f30d0582085af1fDE791D0A9
FeeVault: 0xEF17753B7c690800EA65449A26491887c32536c8
BuybackLocker: 0xBeDc42556ea3312dd643dcE133ed3b5bB5a1C957
CostBasisManager: 0x384492a27ECC0Eb0A2b35FdE719fbb6ae2b4DbAF
Pangu2Staking: 0x6CA7044Baf9336c572F1EE049a3288099c23e894
V2Pair: 0x0Fe75c3460ed320649e133C1AA454881bC6c8b2E
V2Adapter: 0xb3F319303655C61559593cb2968e438F789c79D5
V2Oracle: 0xf16c14B412E69dA6793497AAdf52e38284BcF300
Deployer: 0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53
Governance: 0x6E257B171338BDe98fa1eA3aa62C41AfB0864C53
```

**记下所有地址。** 部署后存为环境变量:

```powershell
$env:PANGU2_TOKEN = "0xToken地址"
$env:PANGU2_ROUTER = "0xTradeRouter地址"
$env:PANGU2_STAKING = "0xStaking地址"
```

---

## 6. 初始化流动性 + Oracle

```powershell
.\deploy-and-test.ps1 -Bootstrap
```

做了: WBNB 兑换 → 添加流动性 → Oracle 首次 Anchor → Pair 注册

状态: ✅ 已部署 | ✅ 配置 | ✅ 流动性 | ⏳ Oracle 累积中

---

## 7. 等待 30 分钟

Oracle 需要完整 `twapWindow`。**中途不要修改储备。**

---

## 8. Finalize Oracle

```powershell
.\deploy-and-test.ps1 -Finalize
```

---

## 9. 验证部署

### 9.1 快速验证

```powershell
.\deploy-and-test.ps1 -VerifyOnly
```

### 9.2 完整部署证据验证

Bash 脚本，需要 `curl` + `jq`（或 `python3`）+ BSC Testnet RPC：

```bash
export BSC_TESTNET_RPC_URL="https://data-seed-prebsc-1-s1.binance.org:8545"
bash scripts/validate-deployment.sh
```

验证项目：
- `eth_getCode` — 11 个合约的链上字节码
- `eth_getTransactionReceipt` — 部署交易确认
- Runtime bytecode hash vs 编译产物
- ABI hash vs 编译产物
- Pair token0/token1 验证
- Factory.getPair 确认
- oracle.pair == pair, oracle.token == token
- Governance 权限矩阵 (hasRole)
- Transfer Context 注册验证
- Deployer 已撤销所有 admin role
- 5 个 config 文件地址一致性验证

验证通过后将 `docs/current/DEPLOYMENT_MANIFEST.md` 中的所有 `UNVERIFIED` 字段填入实际值。

### 9.3 手动验证 (cast)

```bash
# 字节码检查
cast code <contract_address> --rpc-url <rpc_url>

# Storage 读取 (示例: token.isPair)
cast storage <token_address> <storage_slot> --rpc-url <rpc_url>

# 事件日志检查
cast logs --address <token_address> \
  --from-block <deploy_block> --rpc-url <rpc_url>
```



---

## 10. 部署后配置（合约→项目）

部署完成后，需要把合约地址写入以下 **5 个文件**，项目才能跑起来。

### 10.1 contracts-v2\.env

Bootstrap / Finalize 脚本需要这些变量：

```env
# 追加到 contracts-v2\.env 末尾
# ⚠️ 值来自 Stage 1 的输出
PANGU2_TOKEN=<Token 地址>
PANGU2_ORACLE=<V2Oracle 地址>
PANGU2_PAIR=<V2Pair 地址>
```

---

### 10.2 backend\.env（Laravel API）

```env
# 复制 backend\.env.example → backend\.env，然后改下面的值：

# ── 数据库（本地 PostgreSQL）──
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=bnb_presale
DB_USERNAME=postgres
DB_PASSWORD=<你设的 Postgres 密码>

# 如果你用 Docker Compose：
# DB_HOST=postgres
# DB_USERNAME=bnb
# DB_PASSWORD=bnb_dev_pass

# ── Redis ──
REDIS_HOST=127.0.0.1
# 如果用 Docker Compose: REDIS_HOST=redis

# ── 链配置 ──
PANGU2_CHAIN_ID=97
PANGU2_CHAIN_NAME=BSC-Testnet
PANGU2_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
PANGU2_SUPPORTED_NETWORKS=97
PANGU2_DEPLOYMENT_BLOCK=<部署交易的区块号>

# ── 合约地址（⚠️ 全部来自 Stage 1 输出）──
PANGU2_TOKEN_ADDRESS=<Token 地址>
PANGU2_TRADE_ROUTER_ADDRESS=<TradeRouter 地址>
PANGU2_DIVIDEND_DISTRIBUTOR_ADDRESS=<DividendDistributor 地址>
PANGU2_SUPPORT_POOL_ADDRESS=<SupportPool 地址>
PANGU2_BUYBACK_LOCKER_ADDRESS=<BuybackLocker 地址>
PANGU2_FEE_VAULT_ADDRESS=<FeeVault 地址>
PANGU2_COST_BASIS_MANAGER_ADDRESS=<CostBasisManager 地址>
PANGU2_STAKING_ADDRESS=<Pangu2Staking 地址>
PANGU2_WBNB_ADDRESS=0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd

# ── Admin 种子 ──
SEED_ADMIN_PASSWORD=123456
SEED_ADMIN_EMAIL=admin@pangu2.local
SEED_ADMIN_NAME=Super Admin
```

---

### 10.3 apps\dapp\.env（用户 DApp 前端，新建文件）

```env
# 文件路径: E:\github\bnb\bnb-presale-minimal\apps\dapp\.env
VITE_CHAIN_ID=97
VITE_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
VITE_API_BASE_URL=http://localhost:8080/api
VITE_TOKEN_ADDRESS=<Token 地址>
VITE_TRADE_ROUTER_ADDRESS=<TradeRouter 地址>
VITE_STAKING_ADDRESS=<Pangu2Staking 地址>
```

---

### 10.4 apps\admin\.env（Admin 后台，新建文件）

```env
# 文件路径: E:\github\bnb\bnb-presale-minimal\apps\admin\.env
VITE_API_BASE_URL=http://localhost:8080/api
VITE_CHAIN_ID=97
```

---

### 10.5 services\chain-worker\.env（链上事件索引，新建文件）

```env
# 文件路径: E:\github\bnb\bnb-presale-minimal\services\chain-worker\.env
CHAIN_ID=97
CHAIN_WORKER_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545

CHAIN_WORKER_TRADE_ROUTER_ADDRESS=<TradeRouter 地址>
CHAIN_WORKER_DIVIDEND_ADDRESS=<DividendDistributor 地址>
DEPLOYMENT_BLOCK=<部署交易区块号>

DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
DATABASE_NAME=bnb_presale
DATABASE_USER=postgres
DATABASE_PASSWORD=<你设的 Postgres 密码>

START_BLOCK=<部署交易区块号>
SCAN_BATCH_SIZE=1000
CONFIRMATION_BLOCKS=12
REORG_DEPTH=20

WORKER_ID=worker-01
LEASE_TTL_SECONDS=120
SCAN_INTERVAL_SECONDS=15
```

---

### 10.6 启动命令

配置填完后，按以下顺序启动：

```powershell
# 1. 数据库 + 后端（Docker Compose 方式）
cd E:\github\bnb\bnb-presale-minimal
docker compose up -d postgres redis
docker compose up -d backend nginx queue scheduler

# 2. 数据库迁移 + Admin 种子
docker compose exec backend php artisan migrate
docker compose exec backend php artisan db:seed --class=AdminSeeder

# 3. 前端
cd E:\github\bnb\bnb-presale-minimal
pnpm install
cd apps\admin && pnpm dev     # Admin → http://localhost:5174
# 新开终端：
cd apps\dapp && pnpm dev      # DApp  → http://localhost:5173

# 4. Chain Worker（可选）
cd services\chain-worker
pnpm install
pnpm dev
```

---

## 11. 手工测试

### 买卖

```powershell
$rpc = "https://data-seed-prebsc-1-s1.binance.org:8545"
$key = "你的私钥"

# 买入 0.01 BNB
cast send $env:PANGU2_ROUTER "buy(uint256,uint256)" 1 9999999999 --value 0.01ether --rpc-url $rpc --private-key $key

# 查看余额
cast call $env:PANGU2_TOKEN "balanceOf(address)(uint256)" 0x你的地址 --rpc-url $rpc

# 授权 + 卖出
cast send $env:PANGU2_TOKEN "approve(address,uint256)" $env:PANGU2_ROUTER 1000000000000000000000 --rpc-url $rpc --private-key $key
cast send $env:PANGU2_ROUTER "sell(uint256,uint256,uint256)" 100000000000000000000 1 9999999999 --rpc-url $rpc --private-key $key
```

### 锁仓

```powershell
$staking = $env:PANGU2_STAKING
$token = $env:PANGU2_TOKEN

# 1. 授权 Staking 合约
cast send $token "approve(address,uint256)" $staking 1000000000000000000000 --rpc-url $rpc --private-key $key

# 2. 锁仓 1000 Token，锁 90 天
cast send $staking "stake(uint256,uint64)" 1000000000000000000000 7776000 --rpc-url $rpc --private-key $key

# 3. 查看仓位
cast call $staking "positions(address,uint256)((uint256,uint64,uint64,bool))" 0x你的地址 0 --rpc-url $rpc

# 4. 查看可领取收益
cast call $staking "earned(address)(uint256)" 0x你的地址 --rpc-url $rpc
```

### 管理端 (Governance)

```powershell
# 充值奖励池
cast send $staking "fundRewards(uint256)" 100000000000000000000000 --rpc-url $rpc --private-key $key

# 设置奖励速率 (例如: 每天 1 Token ≈ 11574074074074)
cast send $staking "setRewardRate(uint256)" 11574074074074 --rpc-url $rpc --private-key $key

# 查看奖励储备
cast call $staking "availableRewardReserve()(uint256)" --rpc-url $rpc

# 查看质押总量
cast call $staking "totalStaked()(uint256)" --rpc-url $rpc

# 查看偿付能力
cast call $staking "coverageRatio()(uint256,uint256,uint256)" --rpc-url $rpc
```

### 用户端

```powershell
# 到期解锁
cast send $staking "unstake(uint256)" 0 --rpc-url $rpc --private-key $key

# 提前解锁 (扣 10% 罚金 + 没收收益)
cast send $staking "earlyUnstake(uint256)" 0 --rpc-url $rpc --private-key $key

# 单独领取收益 (不解锁本金)
cast send $staking "claimRewards()" --rpc-url $rpc --private-key $key
```

---

## Staking 经济参数

| 参数 | 值 | 说明 |
|---|---|---|
| 最小质押 | 1 Token | `MIN_STAKE = 1 ether` |
| 最大锁期 | 730 天 | `MAX_LOCK_SECONDS` |
| 提前解锁罚金 | 10% | `EARLY_UNSTAKE_PENALTY_BPS = 1000` |
| 最大奖励速率 | ~1 Token/天 | `MAX_REWARD_RATE` |
| 奖励周期 | 30 天 | 每次 `setRewardRate` 默认周期 |
| 罚金去向 | 奖励储备池 | 提升后续锁仓者收益 |

### 奖励管理流程

```text
Governance 钱包 → 转 Token 到 Staking 合约
                 → 调用 fundRewards(amount)
                 → availableRewardReserve 增加
                 → 调用 setRewardRate(rate)
                 → 30 天周期开始
                 → 每 24h 自动从 available 扣减到 accrued
                 → 用户随时调用 claimRewards() 取走
```

---

## 主网部署

编辑 `.env` → `CHAIN_ID=56` + `RPC_URL=https://bsc-dataseed1.binance.org` → 运行 `.\deploy-and-test.ps1`。会显示红色警告。

---

## 故障排除

| 问题 | 解决 |
|---|---|
| insufficient funds | 钱包 BNB 不够 |
| nonce too low | 等上一笔确认 (3秒) |
| in-flight limit | 公共节点限流，等 30s 重试 |
| createPair reverted | Pair 已存在，用 -SkipDeploy |
| unstake StillLocked | 锁仓期未到，查看 `unlockAt` 时间戳 |
| claimRewards 返回 0 | 奖励周期未启动或 `rewardRate=0` |
