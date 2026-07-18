#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p reports/remediation-coverage
LOG="reports/remediation-coverage/coverage-command.log"
LCOV="reports/remediation-coverage/lcov.info"
SUMMARY="reports/remediation-coverage/BNBPresale-coverage-summary.json"
EXPLANATION="reports/remediation-coverage/ANCHOR_WARNING_EXPLANATION_CN.md"
rm -f "$LOG" "$LCOV" "$SUMMARY" "$EXPLANATION" lcov.info

{
    forge --version
    ./tools/solc-wrapper.sh --version
    sha256sum src/BNBPresale.sol test/BNBPresale.t.sol test/ScriptSafety.t.sol foundry.toml
    forge coverage \
        --match-contract BNBPresaleTest \
        --no-match-coverage '(test|script|src/mocks|src/MockSaleToken.sol)' \
        --report lcov \
        --report-file "$LCOV"
} 2>&1 | tee "$LOG"

if [[ ! -s "$LCOV" ]]; then
    echo 'Foundry did not create the requested LCOV file.' >&2
    exit 1
fi

python3 - "$LCOV" "$LOG" "$SUMMARY" "$EXPLANATION" <<'PY'
import json, re, sys
from pathlib import Path

lcov_path, log_path, summary_path, explanation_path = map(Path, sys.argv[1:])
records = lcov_path.read_text().split('end_of_record')
matched = []
for record in records:
    lines = [line.strip() for line in record.splitlines() if line.strip()]
    source = next((line[3:] for line in lines if line.startswith('SF:')), None)
    if source and source.replace('\\', '/').endswith('src/BNBPresale.sol'):
        matched.append(lines)
if len(matched) != 1:
    raise SystemExit(f'Expected exactly one BNBPresale LCOV record, found {len(matched)}')
lines = matched[0]

def value(prefix):
    item = next((line for line in lines if line.startswith(prefix)), None)
    return int(item[len(prefix):]) if item else 0

def pct(found, hit):
    return None if found == 0 else round(hit * 100 / found, 2)

line_found, line_hit = value('LF:'), value('LH:')
fn_found, fn_hit = value('FNF:'), value('FNH:')
br_found, br_hit = value('BRF:'), value('BRH:')
fn_entries = [line for line in lines if line.startswith('FN:')]
receive_names = [line for line in fn_entries if 'BNBPresale.receive' in line]
receive_hits = [line for line in lines if line.startswith('FNDA:') and 'BNBPresale.receive' in line]
warning_count = len(re.findall(r'could not find anchor', log_path.read_text(errors='replace'), flags=re.I))

summary = {
    'source': 'src/BNBPresale.sol',
    'lines': {'found': line_found, 'hit': line_hit, 'percent': pct(line_found, line_hit)},
    'functions': {'found': fn_found, 'hit': fn_hit, 'percent': pct(fn_found, fn_hit)},
    'branches': {'found': br_found, 'hit': br_hit, 'percent': pct(br_found, br_hit)},
    'receive_function_recorded': len(receive_names) == 1,
    'receive_function_hit_recorded': len(receive_hits) == 1 and not receive_hits[0].startswith('FNDA:0,'),
    'anchor_warnings_total': warning_count,
    'anchor_warning_disposition': 'EXPLAINED_SOURCE_MAP_INSTRUMENTATION_LIMITATION',
    'coverage_evidence_status': 'QUALIFIED_NOT_STANDALONE_SECURITY_PROOF',
    'behavioral_evidence_separate': True,
    'final_audit_pass_declared': False,
}

if line_found == 0 or fn_found == 0 or br_found == 0:
    raise SystemExit('Coverage record is incomplete')
if line_hit != line_found or fn_hit != fn_found or br_hit != br_found:
    raise SystemExit(f'Core LCOV counters are not complete: {summary}')
if not summary['receive_function_recorded'] or not summary['receive_function_hit_recorded']:
    raise SystemExit('receive() is not explicitly represented as hit in LCOV')

summary_path.write_text(json.dumps(summary, indent=2) + '\n')
explanation_path.write_text(f'''# Foundry Coverage Anchor 警告处置说明

- 固定 Foundry：见 `coverage-command.log` 首行版本信息；
- 固定 Solidity：`solc-js 0.8.24+commit.e11b9ed9`；
- 原始 anchor 警告数量：**{warning_count}**；
- 处置结论：**已解释并保留，不删除、不隐藏、不把 100% 当作单独安全证明。**

## 原因与边界

本项目通过 `tools/solc-wrapper.sh` 将 Foundry 固定到 solc-js 0.8.24。Foundry 的 coverage anchor 阶段会对编译批次中的生产合约、脚本、测试辅助合约和 mocks 生成大量 `could not find anchor` 警告；这些警告属于 Foundry 与该标准 JSON/source-map 组合的插桩锚点兼容性限制。原始日志完整保存在 `coverage-command.log`。

## 不把警告静默忽略的控制

1. LCOV 只提取 `src/BNBPresale.sol`，脚本、测试和 mocks 不进入核心百分比分母；
2. 机器门禁要求核心合约 Lines、Functions、Branches 的 `found == hit`；
3. 机器门禁额外要求 `BNBPresale.receive` 在 LCOV 中存在且命中次数大于 0；
4. P1-04、P1-05、P1-06 分别由 512 位 `Math.mulDiv` 测试、真实 Anvil 流程、事件/回滚/权限行为矩阵独立验收；
5. 修复报告不得写成“coverage 100% 因而安全”或自行宣布最终 PASS。

## 本次核心 LCOV 计数

- Lines：{line_hit}/{line_found}（{pct(line_found, line_hit)}%）
- Functions：{fn_hit}/{fn_found}（{pct(fn_found, fn_hit)}%）
- Branches：{br_hit}/{br_found}（{pct(br_found, br_hit)}%）
- `receive()`：LCOV 明确存在并命中

因此，P1-07 的修复重点是：重建可复现命令、保存 LCOV 和原始警告、明确解释警告、增加 receive 专项机器校验，并把行为验收从覆盖率百分比中分离。最终是否接受该工具链限制，由独立复审决定。
''')
print(json.dumps(summary, indent=2))
PY
