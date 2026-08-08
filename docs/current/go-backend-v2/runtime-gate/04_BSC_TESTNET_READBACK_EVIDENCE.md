# RT-GATE-02：BSC Testnet Readback 证据（占位）

## 状态

```text
RT-GATE-02_TESTNET_READBACK = BLOCKED_APPROVED_RPC_REQUIRED
READBACK_EXECUTED = NO
DEPLOYMENT_SET_ACTIVE = NO
READY = FALSE
```

## 说明

本文件将在以下前置条件满足后填充：

1. 责任人批准 BSC Testnet RPC PRIMARY 和 BACKUP endpoint
2. RPC 作为环境变量 `BGP_BSC_TESTNET_RPC_PRIMARY` / `BGP_BSC_TESTNET_RPC_BACKUP` 注入
3. Primary 和 Backup 对固定 evidence block 的 number/hash 返回完全一致
4. 对所有 11 个合约 + Pair 执行 `eth_getCode`、key getter `eth_call`、role check、pair verification

## 预期证据区块

```text
block_number = TBD（RPC 就绪后冻结）
block_hash   = TBD
chain_id     = 97
timestamp    = TBD
```

## 证据表格模板

| contract_key | address | code_size | code_hash | getter_checks | verdict |
|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD |

## 当前结论

等待 RPC 批准后执行。不得自行寻找公共 RPC 冒充批准输入。
