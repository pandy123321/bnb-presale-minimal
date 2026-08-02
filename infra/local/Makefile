# ═══════════════════════════════════════════
# PANGU2 Local Dev — Makefile
# Usage:
#   make -C infra/local up      一键启动
#   make -C infra/local down    停止服务
#   make -C infra/local reset   完全重置
#   make -C infra/local health  健康检查
#   make -C infra/local status  服务状态
#   make -C infra/local logs    跟踪日志
# ═══════════════════════════════════════════

COMPOSE_CMD := docker compose -f docker-compose.local.yml

.PHONY: up down reset health status logs logs-err rebuild clean

up:
	@echo "=== 启动 PANGU2 本地开发环境 ==="
	$(COMPOSE_CMD) up -d --build
	@echo ""
	@echo "等待服务就绪（首次启动约需 2-5 分钟）..."
	@sleep 5
	@bash ./health-check.sh

down:
	@echo "=== 停止 PANGU2 本地开发环境 ==="
	$(COMPOSE_CMD) down

reset:
	@echo "=== 完全重置 PANGU2 本地开发环境 ==="
	$(COMPOSE_CMD) down -v
	@sleep 2
	$(COMPOSE_CMD) up -d --build
	@echo ""
	@echo "等待服务就绪..."
	@sleep 5
	@bash ./health-check.sh

health:
	@bash ./health-check.sh

status:
	@echo "=== PANGU2 服务状态 ==="
	@$(COMPOSE_CMD) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

logs:
	$(COMPOSE_CMD) logs -f

logs-err:
	@$(COMPOSE_CMD) logs --tail=50 2>&1 | grep -iE 'error|fail|exception|panic' || echo "未发现错误日志"

rebuild:
	$(COMPOSE_CMD) build --no-cache
	$(COMPOSE_CMD) up -d --force-recreate

clean:
	$(COMPOSE_CMD) down -v
	-docker images -q 'bnb-*' | xargs -r docker rmi -f
	-docker builder prune -f
	@echo "=== 清理完成 ==="
