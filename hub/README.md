# PGBNB Hub

Web3 项目统一存放目录。后续与 Web3 相关的项目都放在本 `hub/` 下，每个项目一个子目录。

## 当前项目

| 目录 | 说明 | 状态 |
|---|---|---|
| `pangu2/` | 盘古2（PANGU2） | 活跃；DR-P2-0001 ACTIVE |
| `pixiu1/` | 原 BNB Presale Minimal（WP-01） | 已归档，只读 |

## 约定

1. 新 Web3 项目：在 `hub/<project-name>/` 下独立创建，不要散落在仓库根目录。
2. 仓库根目录只保留：治理规则（`AGENTS.md`、`.cursor/`、`.agent-rules/`）、共享文档（`docs/governance/`）、以及本 hub。
3. 已归档项目以只读基线对待；盘古2 不得运行时依赖 `pixiu1`，复用须复制后重验。
4. 盘古2 Base Branch：`pgbnb`；产品代码只能进入 `hub/pangu2/`。
