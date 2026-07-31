#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT/reports"
GENERATED_DIR="$REPORT_DIR/generated"
RAW_LOG="$REPORT_DIR/WP01_RAW_COMMAND_LOG.txt"
ENV_REPORT="$REPORT_DIR/WP01_ENVIRONMENT_REPORT.txt"
ABI_REPORT="$REPORT_DIR/WP01_ABI_SHA256.txt"
FILE_SUMS="$REPORT_DIR/WP01_FILE_SHA256SUMS.txt"
FINAL_REPORT="$REPORT_DIR/WP01_BASELINE_REVALIDATION_REPORT_CN.md"
STATUS_FILE="$REPORT_DIR/.wp01-status"

mkdir -p "$GENERATED_DIR"
: > "$RAW_LOG"
: > "$STATUS_FILE"

exec > >(tee -a "$RAW_LOG") 2>&1

mark() {
  printf '%s=%s\n' "$1" "$2" >> "$STATUS_FILE"
}

run_gate() {
  local gate="$1"
  shift
  printf '\n===== GATE %s =====\n' "$gate"
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  if "$@"; then
    mark "$gate" PASS
    printf 'RESULT %s: PASS\n' "$gate"
  else
    local rc=$?
    mark "$gate" "FAIL(rc=$rc)"
    printf 'RESULT %s: FAIL (rc=%s)\n' "$gate" "$rc"
    return "$rc"
  fi
}

on_exit() {
  local rc=$?
  local overall=PASS
  if [[ $rc -ne 0 ]]; then
    overall=FAIL
  fi
  generate_final_report "$overall" "$rc" || true
}
trap on_exit EXIT

generate_final_report() {
  local overall="$1"
  local exit_code="$2"
  local migration_sha abi_frozen_sha abi_generated_sha git_commit
  migration_sha="$(awk '{print $1}' "$REPORT_DIR/WP01_MIGRATION_PACKAGE_SHA256.txt" 2>/dev/null || echo UNKNOWN)"
  abi_frozen_sha="$(sha256sum "$ROOT/contracts/abi/BNBPresale.abi.json" 2>/dev/null | awk '{print $1}' || echo UNKNOWN)"
  abi_generated_sha="$(sha256sum "$GENERATED_DIR/BNBPresale.abi.json" 2>/dev/null | awk '{print $1}' || echo NOT_GENERATED)"
  git_commit="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"

  {
    echo '# WP-01 基线与环境独立复验报告'
    echo
    echo "- 执行时间（UTC）：$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "- Git Commit：\`$git_commit\`"
    echo "- 总体结论：**$overall**"
    echo "- 退出码：\`$exit_code\`"
    echo "- 迁移包 SHA256：\`$migration_sha\`"
    echo "- 冻结 ABI SHA256：\`$abi_frozen_sha\`"
    echo "- 重新导出 ABI SHA256：\`$abi_generated_sha\`"
    echo
    echo '## 范围声明'
    echo
    echo '本次仅执行 WP-01 基线、环境、阶段二合约、Anvil 和 ABI 复验。未修改业务规则，未修改 `PurchaseCompleted` 定义，未开始 Laravel 功能开发。'
    echo
    echo '## 门禁结果'
    echo
    echo '| 门禁 | 结果 |'
    echo '|---|---|'
    if [[ -f "$STATUS_FILE" ]]; then
      while IFS='=' read -r gate result; do
        [[ -n "$gate" ]] && printf '| `%s` | %s |\n' "$gate" "$result"
      done < "$STATUS_FILE"
    fi
    echo
    echo '## 证据文件'
    echo
    echo '- `reports/WP01_RAW_COMMAND_LOG.txt`'
    echo '- `reports/WP01_ENVIRONMENT_REPORT.txt`'
    echo '- `reports/WP01_ABI_SHA256.txt`'
    echo '- `reports/WP01_FILE_SHA256SUMS.txt`'
    echo '- `reports/generated/BNBPresale.abi.json`'
    echo
    echo '## 进入下一阶段条件'
    echo
    if [[ "$overall" == PASS ]]; then
      echo 'WP-01 门禁通过后，方可单独批准进入 WP-02。当前提交本身不包含任何 Laravel 功能开发。'
    else
      echo 'WP-01 未通过。必须先修复环境或阶段二复验失败项，不得开始 Laravel 功能开发。'
    fi
  } > "$FINAL_REPORT"
}

cd "$ROOT"

{
  echo "timestamp_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "os=$(uname -a)"
  echo "git=$(git --version)"
  echo "git_commit=$(git rev-parse HEAD)"
  echo "php=$(php -r 'echo PHP_VERSION;')"
  echo "composer=$(composer --version --no-ansi 2>&1 | head -1)"
  echo "node=$(node --version)"
  echo "npm=$(npm --version)"
  echo "forge=$(forge --version | head -1)"
  echo "anvil=$(anvil --version | head -1)"
  echo "cast=$(cast --version | head -1)"
  echo "psql=$(psql --version)"
  echo "redis_cli=$(redis-cli --version)"
  echo "php_extensions=$(php -m | grep -E '^(bcmath|pdo_pgsql|redis)$' | sort | tr '\n' ',' | sed 's/,$//')"
} > "$ENV_REPORT"
mark ENVIRONMENT_REPORT PASS

run_gate PHP_8_4 bash -lc "php -r 'exit(version_compare(PHP_VERSION, \"8.4.0\", \">=\") ? 0 : 1);'"
run_gate PHP_EXTENSIONS bash -lc "php -m | grep -qx bcmath && php -m | grep -qx pdo_pgsql && php -m | grep -qx redis"
run_gate COMPOSER_AVAILABLE composer --version --no-ansi
run_gate POSTGRES_AVAILABLE pg_isready -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U "${PGUSER:-wp01}" -d "${PGDATABASE:-wp01}"
run_gate POSTGRES_QUERY psql -v ON_ERROR_STOP=1 -c 'SELECT version();'
run_gate REDIS_AVAILABLE redis-cli -h "${REDIS_HOST:-127.0.0.1}" -p "${REDIS_PORT:-6379}" ping
run_gate FOUNDRY_AVAILABLE bash -lc 'forge --version && anvil --version && cast --version'

(
  cd "$ROOT/contracts"
  run_gate NPM_CI npm ci
  run_gate SOLCJS_CHECK npm run solc:check
  run_gate FORGE_FMT forge fmt --check
  run_gate FORGE_CLEAN forge clean
  run_gate FORGE_BUILD forge build
  run_gate FORGE_TEST forge test -vvv
  run_gate FORGE_FUZZ_1000 forge test --fuzz-runs 1000
  run_gate COVERAGE_GATE bash tools/run-coverage-gate.sh
  run_gate FORGE_INSPECT_BYTECODE forge inspect BNBPresale bytecode
  run_gate FORGE_INSPECT_DEPLOYED_BYTECODE forge inspect BNBPresale deployedBytecode
  run_gate FORGE_SNAPSHOT forge snapshot --check
  run_gate ANVIL_INTEGRATION bash tools/run-anvil-integration.sh
)

jq '.abi' "$ROOT/contracts/out/BNBPresale.sol/BNBPresale.json" > "$GENERATED_DIR/BNBPresale.abi.json"
run_gate ABI_JSON_VALID jq -e . "$GENERATED_DIR/BNBPresale.abi.json"

jq -S . "$ROOT/contracts/abi/BNBPresale.abi.json" > /tmp/wp01-frozen-abi.json
jq -S . "$GENERATED_DIR/BNBPresale.abi.json" > /tmp/wp01-generated-abi.json
run_gate ABI_CANONICAL_MATCH cmp -s /tmp/wp01-frozen-abi.json /tmp/wp01-generated-abi.json

{
  echo "frozen_abi_sha256=$(sha256sum "$ROOT/contracts/abi/BNBPresale.abi.json" | awk '{print $1}')"
  echo "generated_abi_sha256=$(sha256sum "$GENERATED_DIR/BNBPresale.abi.json" | awk '{print $1}')"
  echo "frozen_abi_canonical_sha256=$(sha256sum /tmp/wp01-frozen-abi.json | awk '{print $1}')"
  echo "generated_abi_canonical_sha256=$(sha256sum /tmp/wp01-generated-abi.json | awk '{print $1}')"
  echo "canonical_match=PASS"
} > "$ABI_REPORT"
mark ABI_REPORT PASS

(
  cd "$ROOT"
  find contracts docs/current docs/baseline -type f \
    ! -path 'contracts/node_modules/*' \
    ! -path 'contracts/cache/*' \
    ! -path 'contracts/out/*' \
    ! -path 'contracts/broadcast/*' \
    ! -path 'contracts/reports/remediation-build/*' \
    -print0 | sort -z | xargs -0 sha256sum
) > "$FILE_SUMS"
mark FILE_SHA256SUMS PASS

# Ensure WP-01 did not introduce Laravel application development.
run_gate NO_LARAVEL_FEATURE_DEVELOPMENT bash -lc "test ! -d '$ROOT/backend' && ! find '$ROOT' -maxdepth 2 -name artisan -print -quit | grep -q ."

printf '\nWP-01 completed successfully.\n'
