# P2-G03V31 Task Start Gate Record

```text
Project ID: PANGU2
Stage ID: PB-S0
Task ID: P2-G03V31
Task Title: 采用V3.1治理与V1.1拆分开发基线
Task Start Gate: GO
Block Reason: NONE
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Base Branch Tip SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Previous Reviewed Head SHA: NONE
Candidate Ruleset Manifest SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline Manifest SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

## Preconditions

- 工作区必须干净；
- 当前分支必须从`pgbnb`的固定Base SHA创建；
- 必须搜索重复Task、PR和Finding；
- Base Tip变化时停止并重新Gate；
- 第一次正式审核前允许整理Commit，送审后禁止重写历史。
