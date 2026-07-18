# BNB Presale Minimal 项目范围锁定

## 核心业务

用户使用自己控制的非托管钱包，直接向 `BNBPresale` 智能合约地址发送原生 BNB。用户不注册、不登录项目系统，也不连接项目网站钱包。

合约在同一笔交易中完成金额校验、TOKEN 数量计算、TOKEN 发放，并产生 `PurchaseCompleted` 事件；任一步失败时整笔交易回滚。

## Laravel 极简后台范围

1. 管理员 Session 登录和退出；
2. 私募链上状态概览；
3. `PurchaseCompleted` 事件扫描；
4. 购买记录列表和详情；
5. 同步游标、确认状态、RPC 状态；
6. 手动补扫与失败重试；
7. 管理员审计日志；
8. Anvil 端到端测试。

## 明确非范围

用户端、钱包连接、用户注册、KYC、普通钱包收款、后台发币、正式私钥托管、链上签名广播、钱包统计、BNB/TOKEN 独立账本、Pancake 价格、BNB 自动归集、资产对账、Vue、React、多项目、多币种、Claim、Vesting、退款。

## 规则优先级

1. `docs/current/BNB_Presale_极简可视化后台开发规格_V1.0.docx`：当前实施范围；
2. `docs/baseline/`：合约规则、金额精度、安全和状态基线；
3. `contracts/`：阶段二修复后正式合约工程；
4. `backend-reference/`：尚未独立复验的参考代码，不得直接认定可上线。
