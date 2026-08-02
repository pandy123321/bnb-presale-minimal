# P2-I01 验证证据

此目录用于存放 P2-I01（本地开发环境编排）的验证截图和日志。

---

## 需要采集的证据

运行以下命令并截图/保存输出到本目录：

### 1. 冷启动 (`01-cold-start.log`)
```bash
make -C infra/local up 2>&1 | tee docs/evidence/PB-S6/P2-I01/01-cold-start.log
```

### 2. 健康检查 (`02-health.log`)
```bash
make -C infra/local health 2>&1 | tee docs/evidence/PB-S6/P2-I01/02-health.log
```

### 3. 服务状态 (`03-status.log`)
```bash
make -C infra/local status 2>&1 | tee docs/evidence/PB-S6/P2-I01/03-status.log
```

### 4. 数据可重置 (`04-reset.log`)
```bash
make -C infra/local reset 2>&1 | tee docs/evidence/PB-S6/P2-I01/04-reset.log
```

### 5. 各服务端口验证 (`05-ports.log`)
```bash
# PostgreSQL
echo "=== PostgreSQL ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
docker exec bnb-postgres psql -U bnb -d bnb_presale -c "SELECT version();" 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log

# Redis
echo "=== Redis ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
docker exec bnb-redis redis-cli ping 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log

# Anvil
echo "=== Anvil ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log

# Mock API
echo "=== Mock API ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
curl -s http://localhost:4000/health 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log

# DApp
echo "=== DApp ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:5173 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log

# Admin
echo "=== Admin ===" >> docs/evidence/PB-S6/P2-I01/05-ports.log
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:5174 2>&1 >> docs/evidence/PB-S6/P2-I01/05-ports.log
```

### 6. 截图 (`06-screenshots/`)
- `06-screenshots/dapp-homepage.png` — DApp 首页 (http://localhost:5173)
- `06-screenshots/admin-dashboard.png` — Admin 仪表盘 (http://localhost:5174)
- `06-screenshots/mock-api-health.png` — Mock API /health 端点浏览器截图

---

## 验收标准

- [ ] `make up` 一键启动成功，所有服务就绪
- [ ] `make health` 返回全部通过
- [ ] `make reset` 能完全重置环境（数据库清空后仍能启动）
- [ ] DApp 浏览器端显示正常（MOCK_DATA 标签可见）
- [ ] Admin 后台显示正常（仪表盘加载数据）
- [ ] Mock API 返回正确的 JSON Envelope 格式
- [ ] Anvil 链 ID 为 31337，能正常查询区块
- [ ] 不包含任何生产密钥或秘密
