#!/usr/bin/env bash
# 该包装器让 Foundry 使用固定的 solc-js 0.8.24，并规避非阻塞管道兼容问题。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOLCJS="$ROOT_DIR/node_modules/.bin/solcjs"
if [[ ! -x "$SOLCJS" ]]; then
  echo "未找到 solc-js。请先在 contracts 目录执行 npm ci。" >&2
  exit 127
fi
args=()
skip_next=0
is_standard_json=0
for arg in "$@"; do
  if [[ "$skip_next" == "1" ]]; then skip_next=0; continue; fi
  if [[ "$arg" == "--allow-paths" ]]; then skip_next=1; continue; fi
  if [[ "$arg" == "--standard-json" ]]; then is_standard_json=1; fi
  args+=("$arg")
done
if [[ "$is_standard_json" == "1" ]]; then
  input_file="$(mktemp)"
  output_file="$(mktemp)"
  trap 'rm -f "$input_file" "$output_file"' EXIT
  cat > "$input_file"
  "$SOLCJS" "${args[@]}" < "$input_file" > "$output_file"
  # solc-js 会在 JSON 前输出 SMT 提示；只保留从第一个 JSON 对象开始的内容。
  python3 - "$output_file" <<'PYFILTER'
import sys
from pathlib import Path
s = Path(sys.argv[1]).read_text(encoding="utf-8")
pos = s.find("{")
if pos < 0:
    sys.stderr.write(s)
    raise SystemExit(1)
sys.stdout.write(s[pos:])
PYFILTER
else
  exec "$SOLCJS" "${args[@]}"
fi
