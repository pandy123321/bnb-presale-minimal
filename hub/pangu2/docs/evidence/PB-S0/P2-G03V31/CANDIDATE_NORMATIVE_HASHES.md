# P2-G03V31 候选规范哈希

```text
Status: CANDIDATE
Observed Base Branch: pgbnb
Observed Base / Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

权威来源文件：

| 文件 | 用途 |
|---|---|
| [FULL_STARTUP_PACKAGE.md](./FULL_STARTUP_PACKAGE.md) | 启动包全集（含候选哈希） |
| [CURRENT_REPOSITORY_SHA_MANIFEST.md](./CURRENT_REPOSITORY_SHA_MANIFEST.md) | 仓库 Blob SHA 证据 + 候选规范哈希 |
| [VALIDATION_REPORT.md](./VALIDATION_REPORT.md) | 启动包验证报告 |

仓库根同步：`startup_records/`；规格同步：`hub/pangu2/docs/specs/PB-S0/`。

说明：候选 SHA 是执行包本地内容哈希；提交落库后必须另记 Git Blob SHA 与 Current Head SHA。不得把候选哈希直接当作已批准 FROZEN Spec/Ruleset。
