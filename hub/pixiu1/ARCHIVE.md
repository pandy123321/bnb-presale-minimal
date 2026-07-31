# pixiu1（已归档）

原 **BNB Presale Minimal / WP-01** 项目代码与基线，已从仓库根目录归档到本目录。

> 所属 hub：`hub/`（PGBNB Web3 项目集合）  
> 归档原因：仓库升级为 hub 结构，旧项目集中归档，便于后续多 Web3 项目并存。

## 目录

- `contracts/`：阶段二冻结 BNBPresale Foundry 工程
- `docs/current/`：极简可视化后台实施规格
- `docs/baseline/`：阶段一基线文档
- `reports/`：WP-01 复验证据
- `tools/`：WP-01 复验脚本
- `archive/workflows/`：原根目录 GitHub Actions（历史导入/复验流水线，已迁出根目录，不再默认触发）
- `SCOPE_LOCK.md` / `README_MIGRATION_SOURCE.md`：范围与迁移说明

## 本地复验（在归档目录内）

```bash
cd hub/pixiu1
bash tools/wp01-revalidate.sh
```

合约工程：

```bash
cd hub/pixiu1/contracts
forge clean && forge build && forge test -vvv
```

## 注意

- 本目录为归档基线，默认不在此继续扩功能。
- 新 Web3 相关项目请放到 `hub/<新项目名>/`。
- 业务规则与冻结的 `PurchaseCompleted` 事件不得擅自修改。
