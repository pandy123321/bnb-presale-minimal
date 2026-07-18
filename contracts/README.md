# BNB Presale 智能合约（阶段二 P1 修复版）

本目录对应阶段一 `1.1.1-FINAL` 需求基线。修复仅针对独立审计报告 P1-01 至 P1-07，不新增 USDT、退款、Claim、Vesting、推荐、多项目、代理升级或其他业务范围。

## 核心实现

- 仅接收原生 BNB；
- `receive()` 与 `buy()` 共用 `_purchase()`；
- 同交易立即发放 TOKEN；
- 最低、最高、钱包累计额度；
- 重复认购开关；
- 最大销售量和实际库存双重检查；
- `Math.mulDiv` 全精度计算；
- immutable 项目代币；
- 买方余额差额必须精确等于事件和账本记录数量，否则整笔回滚；
- `Ownable2Step`、禁止放弃所有权、`Pausable`、`ReentrancyGuard`；
- 部署后固定保持 PAUSED，部署脚本不提供自动恢复；
- 只向唯一 Treasury 归集 BNB；
- FINALIZED 后才可提取未售 TOKEN。

## 安装与静态编译

```bash
cd contracts
npm ci
node tools/compile-all-solcjs.js
```

`compile-all-solcjs.js` 使用锁定的 `solc-js 0.8.24` 编译生产合约、测试、脚本及可达依赖，并输出：

- `reports/remediation-build/solc-output-summary.json`
- `reports/remediation-build/BNBPresale.abi.json`

## Foundry 完整验证

```bash
forge fmt --check
forge clean
forge build
forge test -vvv
forge test --fuzz-runs 1000
./tools/run-coverage-gate.sh
forge inspect BNBPresale bytecode
forge inspect BNBPresale deployedBytecode
forge snapshot
```

覆盖率门禁会在出现 `could not find anchor` 时直接失败，并只从 LCOV 中提取 `src/BNBPresale.sol` 的可复现结果，不再引用旧的无锚点 100% 摘要。

## 安全部署流程

### 1. 配置

复制 `.env.example`，至少确认：

- `EXPECTED_CHAIN_ID` 与当前 RPC 完全一致；
- `ALLOW_MAINNET_WRITES=false` 为默认值；
- 私钥推导地址等于 `CONTRACT_OWNER_ADDRESS`；
- TOKEN、Treasury、价格、额度、销售上限和库存均为原始整数单位。

### 2. 部署并转入库存

```bash
forge script script/DeployBNBPresale.s.sol:DeployBNBPresale \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast -vvv
```

该脚本：

- 在广播前校验 Chain ID 和主网写入开关；
- 在广播前拒绝 EOA TOKEN；
- 校验初始库存实际增加量必须精确等于 `INITIAL_INVENTORY_RAW`；
- 完成后必须保持 PAUSED；
- 不包含任何自动 `unpause()` 路径。

### 3. 独立核验并激活

将部署地址写入 `PRESALE_ADDRESS`，然后执行：

```bash
forge script script/ActivateBNBPresale.s.sol:ActivateBNBPresale \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast -vvv
```

激活脚本会重新核对 Chain ID、Owner、Treasury、TOKEN、价格、三项额度、重复规则、销售上限、PAUSED/FINALIZED 状态、实际库存和最小购买输出，全部一致后才调用 `unpause()`。

## 本地 Anvil 端到端验证

```bash
./tools/run-anvil-integration.sh
```

脚本使用随机临时账户，验证部署后默认暂停、暂停购买失败、显式恢复、唯一购买事件、精确到账、归集、结束、提取、EOA TOKEN 拒绝、Owner/Chain 门禁和独立激活。临时私钥所在的 Anvil 原始日志会在退出时删除。

## 安全边界

- 项目代币仍必须是标准、无税、无黑名单、无钱包上限和无最大交易限制的 ERC-20/BEP-20；合约余额差额校验用于拒绝常见非精确转账，不宣称能识别所有恶意代币；
- `finalizeSale()` 不可逆；
- Chain 56 即使与 `EXPECTED_CHAIN_ID` 匹配，也必须额外设置 `ALLOW_MAINNET_WRITES=true`；
- 本目录中的修复和命令结果不自行构成最终安全 PASS，最终结论由独立复审作出。
