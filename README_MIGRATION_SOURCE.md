# BNB Presale Minimal 迁移资源包 V1.0

本包用于新建“BNB Presale 极简化功能项目”，不是可直接部署的最终项目。

## 目录说明

- `docs/current/`：当前最高实施规格。
- `docs/baseline/`：必须继承的阶段一冻结规则。
- `docs/reference/`：历史参考，不要求完整实现。
- `contracts/`：阶段二 P1 修复后的完整 Foundry 合约源码、测试、脚本和源码依赖。
- `backend-reference/`：从阶段三筛选的 Laravel 基础代码，仅供重构复用，尚未独立复验。
- `archive/`：少量历史报告和证据，不得替代新项目重新测试。
- `MIGRATION_FILE_INDEX.csv`：每个迁移文件的来源、状态和用途。
- `SOURCE_SHA256SUMS.txt`：本迁移包文件哈希。

## 必须先做

1. 建立新的私有 Git 仓库；
2. 先运行 `contracts/` 的 `forge clean && forge build && forge test -vvv`；
3. 新建或清理 Laravel 13 工程，再从 `backend-reference/` 按需抽取；
4. 不要直接运行 `backend-reference/database/reference-migrations/`；
5. 重新设计极简 Migration，只创建管理员、审计、购买事件、同步游标、任务和异常所需表；
6. 后台必须改成 Blade + Session 登录；
7. 不得迁移真实私钥、助记词、正式 RPC 密钥或生产 `.env`。

## ABI 规则

`contracts/abi/` 中为阶段二参考产物。新项目必须重新编译，并从实际编译结果导出 ABI 到 Laravel 项目。
