# PANGU2 V2 部署文档

版本: V2 (PancakeSwap V2 AMM) | 支持链: BSC Testnet (97) + BSC Mainnet (56) | 更新: 2026-08-03

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
=== PANGU2 V2 Deployed ===
Token: 0x...
TradeRouter: 0x...
DividendDistributor: 0x...
SupportPool: 0x...
FeeVault: 0x...
BuybackLocker: 0x...
V2Pair: 0x...
V2Adapter: 0x...
V2Oracle: 0x...
```

**记下这些地址。**

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

```powershell
.\deploy-and-test.ps1 -VerifyOnly
```

---

## 10. 手工测试

```powershell
$rpc = "https://data-seed-prebsc-1-s1.binance.org:8545"
$key = "你的私钥"
$router = "0xTradeRouter地址"
$token = "0xToken地址"

# 买入 0.01 BNB
cast send $router "buy(uint256,uint256)" 1 9999999999 --value 0.01ether --rpc-url $rpc --private-key $key

# 查看余额
cast call $token "balanceOf(address)(uint256)" 0x你的地址 --rpc-url $rpc

# 授权 + 卖出
cast send $token "approve(address,uint256)" $router 1000000000000000000000 --rpc-url $rpc --private-key $key
cast send $router "sell(uint256,uint256,uint256)" 100000000000000000000 1 9999999999 --rpc-url $rpc --private-key $key
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
