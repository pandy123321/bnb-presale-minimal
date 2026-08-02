# PANGU2 本地开发环境

一键启动 Anvil / PostgreSQL / Redis / Mock API / Laravel / DApp / Admin 全套服务。

---

## 前置条件

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| **Docker** | 24.0+ | 附带 `docker compose` 插件 |
| **Node.js** | 20+ | 仅限宿主开发（Docker 内自动提供） |
| **pnpm** | 9+ | 宿主编排脚本使用（Docker 内自动提供） |
| **Make** | 任意 | 可选，也可用 npm scripts 替代 |
| **bash** | 4.0+ | 健康检查脚本需要 |
| **磁盘** | ≥ 5 GB | 镜像和数据卷占用 |

> Windows 用户：推荐使用 Git Bash、WSL2 或 PowerShell 运行脚本。

---

## 一行启动

```bash
# 从仓库根目录执行（推荐）
make -C infra/local up

# 或使用 docker compose 直接启动
docker compose -f infra/local/docker-compose.local.yml up -d --build

# 或使用 npm scripts
npm --prefix infra/local run up
```

首次启动会拉取镜像并构建，约需 2-5 分钟。

---

## 服务端口一览

| 服务 | 端口 | 用途 | 验证方式 |
|------|------|------|----------|
| **PostgreSQL** | `5432` | 数据库 (bnb_presale) | `psql -h localhost -U bnb -d bnb_presale` |
| **Redis** | `6379` | 缓存 / 队列 | `redis-cli ping` |
| **Anvil** | `8545` | 本地以太坊链 (chain 31337) | `curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545` |
| **Laravel (Nginx)** | `8080` | 后端 API | `curl http://localhost:8080/up` |
| **Mock API** | `4000` | 模拟 API（前后端开发用） | `curl http://localhost:4000/health` |
| **DApp** | `5173` | 用户端 Vue 应用 (热重载) | 浏览器打开 `http://localhost:5173` |
| **Admin** | `5174` | 管理后台 Vue 应用 (热重载) | 浏览器打开 `http://localhost:5174` |

---

## 常用命令

### Makefile (推荐)

```bash
make -C infra/local up        # 启动所有服务
make -C infra/local down      # 停止服务（保留数据）
make -C infra/local reset     # 完全重置（删数据 + 重建）
make -C infra/local health    # 健康检查
make -C infra/local status    # 查看运行状态
make -C infra/local logs      # 跟踪日志
make -C infra/local logs-err  # 查看错误日志
make -C infra/local clean     # 彻底清理（包括镜像）
```

### npm scripts

```bash
npm --prefix infra/local run up
npm --prefix infra/local run down
npm --prefix infra/local run reset
npm --prefix infra/local run health
npm --prefix infra/local run status
npm --prefix infra/local run logs
```

### docker compose 直接操作

```bash
# 启动
docker compose -f infra/local/docker-compose.local.yml up -d --build

# 停止
docker compose -f infra/local/docker-compose.local.yml down

# 完全重置
docker compose -f infra/local/docker-compose.local.yml down -v
docker compose -f infra/local/docker-compose.local.yml up -d --build

# 查看状态
docker compose -f infra/local/docker-compose.local.yml ps

# 进入容器
docker exec -it bnb-postgres psql -U bnb -d bnb_presale
docker exec -it bnb-anvil bash
```

---

## 数据重置

完全重置到干净状态（删除所有数据卷，包括数据库）：

```bash
make -C infra/local reset
```

等价于：

```bash
docker compose -f infra/local/docker-compose.local.yml down -v
docker compose -f infra/local/docker-compose.local.yml up -d --build
```

重置后需要重新运行数据库迁移：

```bash
docker exec -it bnb-php php artisan migrate --seed
```

---

## 开发热重载

DApp 和 Admin 服务使用 Vite 开发服务器，挂载了宿主编源码：

- **DApp**: 修改 `apps/dapp/src/` 下任何文件，浏览器自动刷新
- **Admin**: 修改 `apps/admin/src/` 下任何文件，浏览器自动刷新
- **Mock API**: 修改 `packages/mock-api/src/server.ts`，需重启容器：`docker compose -f infra/local/docker-compose.local.yml restart mock-api`

---

## 常见问题

### 端口被占用
```bash
# 查看占用端口的进程
lsof -i :5432
lsof -i :5173

# 修改端口：编辑 infra/local/docker-compose.local.yml
# 将 ${port}:${port} 左边改为其他端口
```

### Anvil 启动失败
```bash
# 检查日志
docker logs bnb-anvil

# 常见原因：8545 端口被占用
# 停止本地运行的 anvil 进程
```

### Mock API 返回 500
```bash
# 重启 mock API
docker compose -f infra/local/docker-compose.local.yml restart mock-api

# 查看日志
docker logs bnb-mock-api
```

### DApp 页面白屏
```bash
# 确认 Mock API 已启动
curl http://localhost:4000/health

# 确认 Vite 开发服务器运行正常
docker logs bnb-dapp

# 如果是首次启动，等待 30 秒让 Vite 完成构建
```

### 数据库连接失败
```bash
# 确认 PostgreSQL 容器已启动
docker ps | grep bnb-postgres

# 检查 .env 配置（后端 .env 中的 DB_HOST 应为 postgres）
grep DB_HOST backend/.env
```

### 首次启动特别慢
首次启动需要拉取以下镜像（总计约 1.5 GB）：
- `postgres:16-alpine` (~250 MB)
- `redis:7-alpine` (~30 MB)
- `php:8.4-fpm-alpine` (~180 MB)
- `nginx:1.27-alpine` (~50 MB)
- `node:20-alpine` (~120 MB)
- `ghcr.io/foundry-rs/foundry:latest` (~300 MB)

后续启动仅需几秒。

---

## 服务架构

```
┌────────────────────────────────────────────────────┐
│                    本地开发环境                        │
│                                                      │
│  Anvil (8545)    PostgreSQL (5432)    Redis (6379)  │
│  ▼ 本地以太坊链     ▼ 数据库              ▼ 缓存/队列    │
│                                                      │
│  PHP-FPM + Nginx (8080)     Queue Worker             │
│  ▼ Laravel 13 API           ▼ 异步任务                │
│                                                      │
│  Mock API (4000)                                     │
│  ▼ Express — 模拟所有 PANGU2 API 端点，MOCK_DATA       │
│                                                      │
│  DApp (5173)           Admin (5174)                  │
│  ▼ Vue 3 用户端          ▼ Vue 3 管理后台               │
│  proxy → Mock API       proxy → Mock API             │
└──────────────────────────────────────────────────────┘
```

---

## 环境变量

数据库凭据和链配置全部硬编码在 `docker-compose.local.yml` 中，**不含生产密钥**：

| 变量 | 值 | 说明 |
|------|-----|------|
| `POSTGRES_USER` | `bnb` | 开发数据库用户 |
| `POSTGRES_PASSWORD` | `bnb_dev_pass` | 开发数据库密码（非生产） |
| `POSTGRES_DB` | `bnb_presale` | 数据库名 |
| `ANVIL_CHAIN_ID` | `31337` | Anvil 链 ID |
| `ANVIL_BLOCK_TIME` | `2` | 出块间隔（秒） |

---

## 停止与清理

```bash
# 停止（保留数据，下次 up 恢复）
make -C infra/local down

# 停止并删除数据卷（下次启动是全新状态）
docker compose -f infra/local/docker-compose.local.yml down -v

# 完全清理（删除镜像、卷、构建缓存）
make -C infra/local clean
```
