#!/bin/bash
# ═══════════════════════════════════════════
# PANGU2 Local Dev — Health Check
# Checks each service. Run from project root.
# Usage: bash infra/local/health-check.sh
# ═══════════════════════════════════════════

set -e

# Find project root (parent of infra/local/ if running from here)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.local.yml" ]; then
  # Running from infra/local/ — go up to project root
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  PROJECT_ROOT="$(pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0

log_pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
log_fail() { echo -e "  ${RED}✗${NC} $1 — $2"; FAIL=$((FAIL + 1)); }
log_warn() { echo -e "  ${YELLOW}~${NC} $1 — $2"; WARN=$((WARN + 1)); }

# ── TCP port check ──────────────────────────

check_tcp() {
  local name="$1"; local host="$2"; local port="$3"
  if echo "" | nc -z -w3 "$host" "$port" 2>/dev/null; then
    log_pass "$name (TCP $port)"
  elif timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    log_pass "$name (TCP $port)"
  else
    log_fail "$name" "TCP $host:$port 不可达"
  fi
}

# ── HTTP check ──────────────────────────────

check_http() {
  local name="$1"; local url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")

  case "$http_code" in
    200|304) log_pass "$name (HTTP $http_code)" ;;
    000)
      sleep 1
      http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
      case "$http_code" in
        200|304) log_pass "$name (HTTP $http_code, 重试后成功)" ;;
        *) log_fail "$name" "连接失败" ;;
      esac ;;
    *) log_fail "$name" "HTTP $http_code" ;;
  esac
}

check_http_post() {
  local name="$1"; local url="$2"; local data="$3"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null || echo "000")
  if [ "$http_code" = "200" ]; then
    log_pass "$name (HTTP $http_code)"
  else
    log_fail "$name" "RPC 调用失败"
  fi
}

# ── Main ────────────────────────────────────

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  PANGU2 本地开发环境 — 健康检查${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}[数据层]${NC}"
check_tcp "PostgreSQL"  "localhost" 5432
check_tcp "Redis"       "localhost" 6379
echo ""

echo -e "${CYAN}[区块链]${NC}"
check_http_post "Anvil" "http://localhost:8545" \
  '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
echo ""

echo -e "${CYAN}[后端]${NC}"
check_http "Laravel (Nginx)" "http://localhost:8080/up"
echo ""

echo -e "${CYAN}[API / 前端]${NC}"
check_http "Mock API" "http://localhost:4000/health"
check_http "DApp"     "http://localhost:5173"
check_http "Admin"    "http://localhost:5174"
echo ""

# ── Summary ─────────────────────────────────

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -ne "  结果: ${GREEN}$PASS 通过${NC}"
[ $WARN -gt 0 ] && echo -ne "  ${YELLOW}$WARN 警告${NC}"
[ $FAIL -gt 0 ] && echo -ne "  ${RED}$FAIL 失败${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "提示: 部分服务可能仍在启动中。"
  echo "  查看状态: make -C infra/local status"
  echo "  查看日志: make -C infra/local logs"
  echo "  容器列表: docker ps --filter 'name=bnb-'"
  exit 1
fi

echo ""
echo "所有服务就绪！"
echo "  DApp:   http://localhost:5173"
echo "  Admin:  http://localhost:5174"
echo "  API:    http://localhost:8080"
exit 0
