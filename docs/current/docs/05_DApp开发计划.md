# 用户DApp开发计划

```text
Document ID: PANGU2-DAPP-PLAN-1.0
Version: V1.0
Status: PLANNING_BASELINE
Project ID: PANGU2
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Observed Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Target Environment: LOCAL / CI / BSC_TESTNET / STAGING
BSC_MAINNET: NO-GO
Automatic Merge: FORBIDDEN
Automatic Deployment: FORBIDDEN
Prepared At: 2026-08-01
```

> `Observed Base SHA` 是本文件生成时观察值。每个Task开始前必须重新读取Base Branch Tip并固定 `Task Start Base SHA`。

## 1. 页面

```text
/
├─ 首页
├─ 交易
├─ 分红
├─ 托底
└─ 我的
```

## 2. DApp任务

```text
F01 Vue工程、路由、设计系统
F02 Wallet与Network
F03 API Client与全局状态
F04 Trade页面与Quote
F05 Approval/Signature/Transaction状态机
F06 Dividend/Support/My
F07 Error/Recovery/Accessibility/E2E
```

## 3. 并行规则

F01可与B01并行；F02/F03可与B02/B03并行；F04/F05可先用Mock与B04/B05并行；F06正式LIVE等待B06和PB-S1事件。

## 4. 硬规则

- 不提供4%/10%选择；
- 不在前端判定盈利；
- `previewSell`结果来自合约或API代理；
- 授权和卖出显示为两笔独立交易；
- 报价显示引用区块、过期时间、数据状态；
- 买入MAX预留Gas；
- 估算排名、结算排名和可领取结果分开；
- 非LIVE数据显式显示；
- 不显示未批准的固定锁仓期限；
- 用户资产操作必须由钱包签名。

## 5. DApp Definition of Done

- Mobile-first；
- Wallet/Network/Quote/Approval/Signature/Tx/Claim状态覆盖；
- 用户拒签、交易替换、丢弃、重组和数据STALE有明确UI；
- API Client来自生成包；
- Mock与LIVE切换不改变页面业务逻辑；
- 单元、组件、构建和E2E通过。
