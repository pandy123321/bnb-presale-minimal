#!/usr/bin/env bash
set -euo pipefail

# 仅用于本地 Anvil 集成测试。每次运行随机生成临时账户，不在仓库中保存任何私钥。
PORT="${ANVIL_TEST_PORT:-18545}"
RPC="http://127.0.0.1:${PORT}"
REPORT_DIR="reports/anvil-remediation"
mkdir -p "$REPORT_DIR"
rm -f reports/ANVIL_INTEGRATION_RESULT.json reports/ANVIL_INTEGRATION_REPORT_CN.md
rm -rf broadcast/DeployLocal.s.sol/31337 broadcast/DeployBNBPresale.s.sol/31337 \
    broadcast/ActivateBNBPresale.s.sol/31337

exec > "$REPORT_DIR/full-command.log" 2>&1

echo "[toolchain] forge/anvil/cast/node/npm versions"

forge --version
anvil --version
cast --version
node --version
npm --version

setsid anvil --host 127.0.0.1 --port "$PORT" --chain-id 31337 --mnemonic-random 12 \
    > "$REPORT_DIR/anvil-local-sensitive.log" 2>&1 &
ANVIL_PID=$!
cleanup() {
    kill -- "-$ANVIL_PID" 2>/dev/null || true
    # Anvil 原始日志含本次临时私钥，只在解析期间存在，退出时强制删除。
    rm -f "$REPORT_DIR/anvil-local-sensitive.log"
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 50); do
    if cast chain-id --rpc-url "$RPC" >/dev/null 2>&1; then break; fi
    sleep 0.2
done
[ "$(cast chain-id --rpc-url "$RPC")" = "31337" ]

OWNER=$(awk '/Available Accounts/{f=1;next}/Private Keys/{f=0} f && /^\(0\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
TREASURY=$(awk '/Available Accounts/{f=1;next}/Private Keys/{f=0} f && /^\(1\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
BUYER=$(awk '/Available Accounts/{f=1;next}/Private Keys/{f=0} f && /^\(2\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
WRONG_OWNER=$(awk '/Available Accounts/{f=1;next}/Private Keys/{f=0} f && /^\(3\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
OWNER_PK=$(awk '/Private Keys/{f=1;next}/Wallet/{f=0} f && /^\(0\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
BUYER_PK=$(awk '/Private Keys/{f=1;next}/Wallet/{f=0} f && /^\(2\)/ {print $2}' "$REPORT_DIR/anvil-local-sensitive.log")
[ -n "$OWNER" ] && [ -n "$TREASURY" ] && [ -n "$BUYER" ] && [ -n "$WRONG_OWNER" ]
[ -n "$OWNER_PK" ] && [ -n "$BUYER_PK" ]

export LOCAL_RPC_URL="$RPC"
export DEPLOYER_PRIVATE_KEY="$OWNER_PK"
export CONTRACT_OWNER_ADDRESS="$OWNER"
export TREASURY_ADDRESS="$TREASURY"
export EXPECTED_CHAIN_ID=31337
export ALLOW_MAINNET_WRITES=false

# 1-4：本地部署必须完成“部署后 PAUSED + 库存到账”，不得自动恢复。
echo "[step 1-4] forge script DeployLocal (private key redacted)"
forge script script/DeployLocal.s.sol:DeployLocal --rpc-url "$RPC" --broadcast --skip-simulation --offline \
    > "$REPORT_DIR/deploy-local.log" 2>&1
TOKEN=$(jq -r '.transactions[] | select(.contractName=="MockSaleToken" and .transactionType=="CREATE") | .contractAddress' \
    broadcast/DeployLocal.s.sol/31337/run-latest.json)
PRESALE=$(jq -r '.transactions[] | select(.contractName=="BNBPresale" and .transactionType=="CREATE") | .contractAddress' \
    broadcast/DeployLocal.s.sol/31337/run-latest.json)
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] && [ -n "$PRESALE" ] && [ "$PRESALE" != "null" ]
[ "$(cast code "$TOKEN" --rpc-url "$RPC")" != "0x" ]
[ "$(cast code "$PRESALE" --rpc-url "$RPC")" != "0x" ]
[ "${OWNER,,}" = "$(cast call "$PRESALE" 'owner()(address)' --rpc-url "$RPC" | tr '[:upper:]' '[:lower:]')" ]
[ "${TREASURY,,}" = "$(cast call "$PRESALE" 'treasuryAddress()(address)' --rpc-url "$RPC" | tr '[:upper:]' '[:lower:]')" ]
[ "$(cast call "$PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "true" ]
[ "$(cast call "$PRESALE" 'saleFinalized()(bool)' --rpc-url "$RPC")" = "false" ]
INVENTORY_INITIAL=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$PRESALE" --rpc-url "$RPC" | awk '{print $1}')
[ "$INVENTORY_INITIAL" = "100000000000000000000000000" ]

# 5：PAUSED 时购买必须失败，状态、余额与事件均不改变。
BUYER_TOKEN_BEFORE_PAUSED=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')
PRESALE_BNB_BEFORE_PAUSED=$(cast balance "$PRESALE" --rpc-url "$RPC")
set +e
cast send "$PRESALE" --value 1ether --private-key "$BUYER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/purchase-while-paused.out" 2> "$REPORT_DIR/purchase-while-paused.err"
PAUSED_PURCHASE_RC=$?
set -e
[ "$PAUSED_PURCHASE_RC" -ne 0 ]
[ "$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')" = "$BUYER_TOKEN_BEFORE_PAUSED" ]
[ "$(cast balance "$PRESALE" --rpc-url "$RPC")" = "$PRESALE_BNB_BEFORE_PAUSED" ]
[ "$(cast call "$PRESALE" 'totalBNBRaised()(uint256)' --rpc-url "$RPC" | awk '{print $1}')" = "0" ]

# 6：库存与配置核验完成后，显式单独恢复。
cast send "$PRESALE" 'unpause()' --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/unpause-receipt.json"
jq -e '.status=="0x1"' "$REPORT_DIR/unpause-receipt.json" >/dev/null
[ "$(cast call "$PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "false" ]

# 7-10：receive 购买、唯一事件、即时精确到账与累计统计。
cast send "$PRESALE" --value 1ether --private-key "$BUYER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/purchase-receipt.json"
jq -e '.status=="0x1"' "$REPORT_DIR/purchase-receipt.json" >/dev/null
PURCHASE_TX=$(jq -r .transactionHash "$REPORT_DIR/purchase-receipt.json")
PURCHASE_TOPIC=$(cast keccak 'PurchaseCompleted(address,uint256,uint256,uint256,uint256,uint256,uint256)')
PURCHASE_EVENT_COUNT=$(jq --arg topic "${PURCHASE_TOPIC,,}" \
    '[.logs[] | select((.topics[0] | ascii_downcase) == $topic)] | length' "$REPORT_DIR/purchase-receipt.json")
[ "$PURCHASE_EVENT_COUNT" = "1" ]
BUYER_TOKEN=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')
PRESALE_BNB_AFTER_PURCHASE=$(cast balance "$PRESALE" --rpc-url "$RPC")
WALLET_SPENT=$(cast call "$PRESALE" 'walletBNBSpent(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')
WALLET_RECEIVED=$(cast call "$PRESALE" 'walletTokensReceived(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')
WALLET_COUNT=$(cast call "$PRESALE" 'walletPurchaseCount(address)(uint256)' "$BUYER" --rpc-url "$RPC" | awk '{print $1}')
TOTAL_RAISED=$(cast call "$PRESALE" 'totalBNBRaised()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
TOTAL_SOLD=$(cast call "$PRESALE" 'totalTokensSold()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
[ "$BUYER_TOKEN" = "100000000000000000000000" ]
[ "$PRESALE_BNB_AFTER_PURCHASE" = "1000000000000000000" ]
[ "$WALLET_SPENT" = "1000000000000000000" ]
[ "$WALLET_RECEIVED" = "100000000000000000000000" ]
[ "$WALLET_COUNT" = "1" ]
[ "$TOTAL_RAISED" = "1000000000000000000" ]
[ "$TOTAL_SOLD" = "100000000000000000000000" ]

# 11-12：只向 Treasury 归集 0.5 BNB。
TREASURY_BEFORE=$(cast balance "$TREASURY" --rpc-url "$RPC")
cast send "$PRESALE" 'sweepBNB(uint256)' 500000000000000000 --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/sweep-receipt.json"
jq -e '.status=="0x1"' "$REPORT_DIR/sweep-receipt.json" >/dev/null
SWEEP_TX=$(jq -r .transactionHash "$REPORT_DIR/sweep-receipt.json")
TREASURY_AFTER=$(cast balance "$TREASURY" --rpc-url "$RPC")
PRESALE_BNB_AFTER_SWEEP=$(cast balance "$PRESALE" --rpc-url "$RPC")
python3 - <<PY
assert int("$TREASURY_AFTER") - int("$TREASURY_BEFORE") == 500000000000000000
assert int("$PRESALE_BNB_AFTER_SWEEP") == 500000000000000000
PY

# 13-16：暂停、永久结束、提取未售 TOKEN、结束后禁止恢复。
cast send "$PRESALE" 'pause()' --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/pause-receipt.json"
cast send "$PRESALE" 'finalizeSale()' --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/finalize-receipt.json"
jq -e '.status=="0x1"' "$REPORT_DIR/finalize-receipt.json" >/dev/null
FINALIZE_TX=$(jq -r .transactionHash "$REPORT_DIR/finalize-receipt.json")
[ "$(cast call "$PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "true" ]
[ "$(cast call "$PRESALE" 'saleFinalized()(bool)' --rpc-url "$RPC")" = "true" ]
OWNER_TOKEN_BEFORE=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$OWNER" --rpc-url "$RPC" | awk '{print $1}')
WITHDRAW_AMOUNT="1000000000000000000000000"
cast send "$PRESALE" 'withdrawUnsoldTokens(address,uint256)' "$OWNER" "$WITHDRAW_AMOUNT" \
    --private-key "$OWNER_PK" --rpc-url "$RPC" --json > "$REPORT_DIR/withdraw-receipt.json"
jq -e '.status=="0x1"' "$REPORT_DIR/withdraw-receipt.json" >/dev/null
WITHDRAW_TX=$(jq -r .transactionHash "$REPORT_DIR/withdraw-receipt.json")
OWNER_TOKEN_AFTER=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$OWNER" --rpc-url "$RPC" | awk '{print $1}')
INVENTORY_FINAL=$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$PRESALE" --rpc-url "$RPC" | awk '{print $1}')
python3 - <<PY
assert int("$OWNER_TOKEN_AFTER") - int("$OWNER_TOKEN_BEFORE") == int("$WITHDRAW_AMOUNT")
assert int("$INVENTORY_FINAL") == 98900000000000000000000000
PY
set +e
cast send "$PRESALE" 'unpause()' --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/unpause-after-finalize.out" 2> "$REPORT_DIR/unpause-after-finalize.err"
UNPAUSE_FINAL_RC=$?
set -e
[ "$UNPAUSE_FINAL_RC" -ne 0 ]
[ "$(cast call "$PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "true" ]

# 17：生产型部署的 EOA TOKEN 必须在广播前失败，且不得生成成功部署记录。
export SALE_TOKEN_ADDRESS="$WRONG_OWNER"
export TOKEN_PER_BNB_RAW=100000000000000000000000
export MIN_PURCHASE_BNB_WEI=10000000000000000
export MAX_PURCHASE_BNB_WEI=10000000000000000000
export MAX_PURCHASE_PER_WALLET_WEI=50000000000000000000
export ALLOW_REPEAT_PURCHASE=true
export MAX_TOKENS_SOLD_RAW=2000000000000000000000000
export INITIAL_INVENTORY_RAW=2000000000000000000000000
rm -rf broadcast/DeployBNBPresale.s.sol/31337
set +e
echo "[step 17] production deploy with EOA token must fail before broadcast"
forge script script/DeployBNBPresale.s.sol:DeployBNBPresale --rpc-url "$RPC" --broadcast --offline \
    > "$REPORT_DIR/deploy-eoa-token.out" 2> "$REPORT_DIR/deploy-eoa-token.err"
EOA_DEPLOY_RC=$?
set -e
[ "$EOA_DEPLOY_RC" -ne 0 ]
grep -q 'InvalidConfiguredContract' "$REPORT_DIR/deploy-eoa-token.out" "$REPORT_DIR/deploy-eoa-token.err"
[ ! -f broadcast/DeployBNBPresale.s.sol/31337/run-latest.json ]

# 18：既有标准 TOKEN 部署后保持 PAUSED，再由独立激活脚本核验并恢复。
export SALE_TOKEN_ADDRESS="$TOKEN"
echo "[step 18a] production-style deploy remains paused"
forge script script/DeployBNBPresale.s.sol:DeployBNBPresale --rpc-url "$RPC" --broadcast --skip-simulation --offline \
    > "$REPORT_DIR/deploy-existing-token.log" 2>&1
SECOND_PRESALE=$(jq -r '.transactions[] | select(.contractName=="BNBPresale" and .transactionType=="CREATE") | .contractAddress' \
    broadcast/DeployBNBPresale.s.sol/31337/run-latest.json)
[ "$(cast call "$SECOND_PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "true" ]
[ "$(cast call "$TOKEN" 'balanceOf(address)(uint256)' "$SECOND_PRESALE" --rpc-url "$RPC" | awk '{print $1}')" \
    = "2000000000000000000000000" ]
export PRESALE_ADDRESS="$SECOND_PRESALE"
echo "[step 18b] independent activation after checks"
forge script script/ActivateBNBPresale.s.sol:ActivateBNBPresale --rpc-url "$RPC" --broadcast --skip-simulation --offline \
    > "$REPORT_DIR/activate-existing-token.log" 2>&1
[ "$(cast call "$SECOND_PRESALE" 'paused()(bool)' --rpc-url "$RPC")" = "false" ]

# 额外门禁：错误 Owner 与错误 Chain ID 均须在广播前失败。
export CONTRACT_OWNER_ADDRESS="$WRONG_OWNER"
set +e
forge script script/DeployBNBPresale.s.sol:DeployBNBPresale --rpc-url "$RPC" --offline \
    > "$REPORT_DIR/deploy-owner-mismatch.out" 2> "$REPORT_DIR/deploy-owner-mismatch.err"
OWNER_MISMATCH_RC=$?
set -e
[ "$OWNER_MISMATCH_RC" -ne 0 ]
grep -q 'PrivateKeyOwnerMismatch' "$REPORT_DIR/deploy-owner-mismatch.out" "$REPORT_DIR/deploy-owner-mismatch.err"

export CONTRACT_OWNER_ADDRESS="$OWNER"
export EXPECTED_CHAIN_ID=97
set +e
forge script script/DeployBNBPresale.s.sol:DeployBNBPresale --rpc-url "$RPC" --offline \
    > "$REPORT_DIR/deploy-chain-mismatch.out" 2> "$REPORT_DIR/deploy-chain-mismatch.err"
CHAIN_MISMATCH_RC=$?
set -e
[ "$CHAIN_MISMATCH_RC" -ne 0 ]
grep -q 'UnexpectedChainId' "$REPORT_DIR/deploy-chain-mismatch.out" "$REPORT_DIR/deploy-chain-mismatch.err"
export EXPECTED_CHAIN_ID=31337

# 激活后的第二份私募恢复为 PAUSED，避免测试退出时留下活动销售。
echo "[cleanup-state] pause second presale"
cast send "$SECOND_PRESALE" 'pause()' --private-key "$OWNER_PK" --rpc-url "$RPC" --json \
    > "$REPORT_DIR/second-presale-pause-receipt.json"
echo "[report] writing machine result and Chinese report"

export TOKEN PRESALE OWNER TREASURY BUYER INVENTORY_INITIAL PURCHASE_TX BUYER_TOKEN WALLET_SPENT WALLET_RECEIVED \
    WALLET_COUNT TOTAL_RAISED TOTAL_SOLD SWEEP_TX PRESALE_BNB_AFTER_SWEEP FINALIZE_TX WITHDRAW_TX INVENTORY_FINAL \
    SECOND_PRESALE PURCHASE_EVENT_COUNT
python3 - <<'PY'
import json, os
from pathlib import Path
r = Path('reports')
data = {
    'result': 'COMMANDS_PASSED_NOT_FINAL_AUDIT_PASS',
    'chain_id': 31337,
    'token_address': os.environ['TOKEN'],
    'presale_address': os.environ['PRESALE'],
    'purchase_transaction': os.environ['PURCHASE_TX'],
    'purchase_completed_event_count': int(os.environ['PURCHASE_EVENT_COUNT']),
    'sweep_transaction': os.environ['SWEEP_TX'],
    'finalize_transaction': os.environ['FINALIZE_TX'],
    'withdraw_transaction': os.environ['WITHDRAW_TX'],
    'buyer_token_raw': os.environ['BUYER_TOKEN'],
    'presale_bnb_after_sweep_wei': os.environ['PRESALE_BNB_AFTER_SWEEP'],
    'finalized': True,
    'unpause_after_finalize_reverted': True,
    'existing_token_deployment_address': os.environ['SECOND_PRESALE'],
    'deployment_default_paused_verified': True,
    'explicit_activation_verified': True,
    'eoa_token_prebroadcast_rejected': True,
    'private_key_owner_mismatch_rejected': True,
    'chain_id_mismatch_rejected': True,
}
(r / 'ANVIL_INTEGRATION_RESULT.json').write_text(json.dumps(data, indent=2) + '\n')
report = f'''# 阶段二 P1 修复后 Anvil 集成验证报告

验证结论：**本脚本全部机器断言通过；不构成独立复审最终 PASS。**

## 已验证流程

| 流程 | 结果 |
|---|---|
| Chain ID 31337 与随机临时账户 | 通过 |
| DeployLocal 部署后保持 PAUSED | 通过 |
| 初始库存精确到账 | 通过 |
| PAUSED 购买失败且状态不变 | 通过 |
| 核验后显式 unpause | 通过 |
| receive 购买成功 | 通过 |
| `PurchaseCompleted` 恰好 1 个 | 通过 |
| Buyer 精确即时收到 TOKEN | 通过 |
| 全局与钱包累计统计 | 通过 |
| 仅向 Treasury 归集 BNB | 通过 |
| pause → finalize 不可逆 | 通过 |
| FINALIZED 后提取未售 TOKEN | 通过 |
| FINALIZED 后 unpause 失败 | 通过 |
| EOA TOKEN 在广播前拒绝且无部署记录 | 通过 |
| 生产型部署保持 PAUSED | 通过 |
| 独立激活脚本完成配置、库存与状态核验 | 通过 |
| 私钥与 Owner 不匹配在广播前拒绝 | 通过 |
| Chain ID 不匹配在广播前拒绝 | 通过 |

- 主私募：`{os.environ['PRESALE']}`
- 第二份生产型私募：`{os.environ['SECOND_PRESALE']}`
- 购买交易：`{os.environ['PURCHASE_TX']}`
'''
(r / 'ANVIL_INTEGRATION_REPORT_CN.md').write_text(report)
PY

echo 'ANVIL_INTEGRATION_COMMANDS=PASSED_NOT_FINAL_AUDIT_PASS'
