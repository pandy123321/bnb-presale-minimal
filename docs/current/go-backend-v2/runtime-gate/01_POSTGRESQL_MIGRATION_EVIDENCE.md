# RT-GATE-01：PostgreSQL Migration 证据

## 状态

```text
RT-GATE-01_POSTGRESQL_MIGRATION = BLOCKED_POSTGRESQL_NOT_AVAILABLE
```

## 目标 PostgreSQL 版本

根据 `sql/0001_binggoplus_v2_schema.sql` 第 2 行声明：

```text
PostgreSQL 16+
```

冻结文档未指定精确 minor/patch。执行环境必须记录 `SELECT version()` 输出后填入。在本证据产出时，精确版本为：

```text
POSTGRESQL_VERSION = NOT_AVAILABLE（执行环境无 PostgreSQL 实例）
```

## 环境检测结果

| 检查项 | 结果 |
|---|---|
| `psql` 命令可用 | 不可用 |
| `pg_isready` 命令可用 | 不可用 |
| Docker 可用 | 未检测 |
| 已有 PostgreSQL 实例可达 | 否 |

## 目标隔离环境规格

按照冻结文档 `02_DATABASE_FREEZE.md` 和 `06_DEPLOYMENT_ENVIRONMENT.md` 要求：

```text
database  = binggoplus_go
schema    = binggoplus_v2
host      = 隔离、非生产、无真实业务数据
connect   = 仅允许批准角色
```

## 必须创建的角色

| Role | 权限类 | 用途 |
|---|---|---|
| `bgp_migrator` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 唯一 Schema/DDL 所有者，仅在 Migration 时使用 |
| `bgp_api` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | Public/Admin API |
| `bgp_indexer` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | Block/Log 扫描 |
| `bgp_projector` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 事件→读模型投影 |
| `bgp_dividend` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 分红 Artifact 构建 |
| `bgp_reconciler` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 治理交易签名/广播 |
| `bgp_auditor` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 审计只读 |
| `bgp_readonly` | LOGIN, NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS | 产品只读 |

所有角色必须通过平台预先创建（含密码/Secret），仓库脚本不创建密码。

## Migration 执行计划（待执行）

执行顺序：

1. 以 `bgp_migrator` 连接隔离数据库 `binggoplus_go`
2. 执行 `0001_binggoplus_v2_schema.sql`
3. 执行 `0002_binggoplus_v2_runtime_privileges.sql`
4. 记录执行前后 timestamp、exit code、SQLSTATE（如失败）

### Migration 0001 预期范围

- 创建 Schema `binggoplus_v2`
- 创建 domains：`evm_address`、`evm_hash`、`uint256_numeric`、`bps_value`
- 创建 43 张表 + 4 个 Dividend `security_barrier` 视图
- 创建多个 Trigger/Function（状态机强制、append-only 保护、身份不可变）
- 创建复合外键与条件唯一索引

### Migration 0002 预期范围

- 验证 7 个运行时角色存在且集群权限干净
- 撤销 PUBLIC 所有权限
- 为每个角色授予冻结最小权限
- 设置 `ALTER DEFAULT PRIVILEGES` 拒绝未来 PUBLIC 默认权限

## 迁移失败处理

如 Migration 任一步骤失败：

```text
RT-GATE-01 = FAILED
```

必须保存原始错误（`SQLSTATE`、错误消息、失败语句上下文），不得修改 SQL 后静默重跑。由独立修复流程处理。

## 当前结论

Migration 因执行环境无 PostgreSQL 16+ 实例而无法执行。需要：

1. 责任人批准并配置隔离 PostgreSQL 环境（本机独立安装 / Docker / CI PostgreSQL Service）
2. 平台预先创建 8 个 LOGIN Role（密码不在仓库内）
3. 以 `bgp_migrator` 依次执行两份 SQL
4. 记录全量执行证据后重新评估 RT-GATE-01
