# PGBNB

Web3 项目 hub 仓库。

## 结构

```text
.
├── AGENTS.md                 # 三 Agent 云端治理入口
├── .agent-rules/             # 角色规则规范副本
├── .cursor/rules/            # Cursor 可执行规则
├── docs/governance/          # 仓库级治理文档
└── hub/                      # 所有 Web3 相关项目
    ├── README.md
    └── pixiu1/               # 已归档：原 BNB Presale Minimal（WP-01）
```

## 约定

- **以后所有与 Web3 相关的项目，都放在 `hub/` 目录下。**
- 每个项目使用独立子目录，例如 `hub/pixiu1/`、`hub/<new-project>/`。
- 仓库根目录不直接放业务合约/前端/后台代码。
- 治理与 Agent 规则保留在仓库根，适用于整个 hub。

## 已归档项目

- [`hub/pixiu1/`](./hub/pixiu1/ARCHIVE.md)：原 BNB Presale Minimal WP-01 基线与合约工程。
