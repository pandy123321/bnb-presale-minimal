# Required Check Manifest — P2-G03V31

```text
Manifest ID: P2-G03V31-CHECKS-1.0
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Spec SHA: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Candidate Ruleset SHA: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
```

| Check Name | Applicability | Reason | Workflow File | Expected Job | Observed Status at Base | Head SHA | Evidence |
|---|---|---|---|---|---|---|---|
| markdown-lint | REQUIRED | 全部为Markdown/MDX规则 | `<TO_BE_IMPLEMENTED>` | markdown-lint | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | log |
| baseline-structure-check | REQUIRED | 文件、章节、模板完整 | `<TO_BE_IMPLEMENTED>` | baseline-structure | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| decision-reference-check | REQUIRED | Decision/PFR不可伪造 | `<TO_BE_IMPLEMENTED>` | decision-reference | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| internal-link-check | REQUIRED | 文档跨链路 | `<TO_BE_IMPLEMENTED>` | link-check | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| secret-scan | REQUIRED | 禁止凭证 | `<TO_BE_IMPLEMENTED>` | secret-scan | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| forbidden-path-check | REQUIRED | 纯文档任务 | `<TO_BE_IMPLEMENTED>` | forbidden-path | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | diff |
| duplicate-normative-source | REQUIRED | 参数唯一来源 | `<TO_BE_IMPLEMENTED>` | duplicate-source | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| old-tier-active-use | REQUIRED | 禁止恢复35/25/25/15 | `<TO_BE_IMPLEMENTED>` | tier-check | NOT_IMPLEMENTED | `<CURRENT_HEAD>` | report |
| product-code-tests | NOT_APPLICABLE | 本Task禁止产品代码 | NONE | NONE | NOT_APPLICABLE | `<CURRENT_HEAD>` | Forbidden Path证明 |

## Rules

- `skipped`不是PASS；
- Path filter必须覆盖全部Allowed Paths；
- 报告为空或检查数为0时不得PASS；
- CI未实现时执行Agent必须提供本地等价证据，Closeout记录仍标CI `NOT_IMPLEMENTED`。
