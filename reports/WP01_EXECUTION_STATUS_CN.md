# WP-01 执行状态

## 已完成

- 从迁移包原样导入 `contracts/`、`docs/current/`、`docs/baseline/`；
- 对 252 个导入文件逐一执行 SHA256 对比，结果全部一致；
- 锁定迁移包 SHA256；
- 建立本地 Git `main` 基线与 WP-01 CI 提交；
- 增加 GitHub Actions WP-01 复验工作流；
- 增加环境、Foundry 全量测试、Anvil、ABI 重导出和证据报告脚本；
- 未修改业务规则，未开始 Laravel 功能开发。

## 尚未完成

远程 GitHub 私有仓库尚未创建，因此工作流尚未推送和执行。当前运行容器只有 PHP 8.4，且无法通过系统包源解析域名安装 Composer、PostgreSQL、Redis、PHP 扩展和 Foundry；该本地环境不得标记为通过。

## 远程仓库建立后自动执行的门禁

- PHP 8.4 与 `bcmath`、`pdo_pgsql`、`redis`；
- Composer；
- PostgreSQL 实际连接与查询；
- Redis 实际 PING；
- Forge、Anvil、Cast；
- `npm ci` 与 solc-js 编译；
- `forge fmt --check`、clean、build、完整测试、1000 fuzz、coverage、bytecode、snapshot；
- Anvil 端到端集成；
- ABI 重新导出、规范化对比和 SHA256；
- WP-01 中文报告、环境报告、原始命令日志与文件哈希清单。
