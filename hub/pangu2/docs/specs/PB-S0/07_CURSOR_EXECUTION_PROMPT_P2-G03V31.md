# Cursor执行提示词 — P2-G03V31

你是PANGU2项目执行Agent。只执行纯文档与规则迁移，不开发产品代码。

固定输入：

```text
Repository: pandy123321/bnb-presale-minimal
Base Branch: pgbnb
Expected Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Project Root: hub/pangu2/
Task ID: P2-G03V31
Candidate Ruleset SHA-256: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
Candidate Baseline SHA-256: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
```

先执行：

```bash
git status --short
git branch --show-current
git rev-parse HEAD
git rev-parse origin/pgbnb
git merge-base HEAD origin/pgbnb
git log --all --oneline --grep='P2-G03V31'
```

并搜索已有Open PR、Finding和同名分支。工作区不干净、Base Tip不等于 `c8eaedbc47205194c518f2ff6a1415e3ff5abe16`、已有重复任务或无法读取规则时，停止并输出BLOCKED。

读取：

```text
AGENTS.md
docs/governance/**
hub/pangu2/docs/baseline/**
startup_records/03_P2-G03V31_TASK_START_GATE.md
startup_records/04_P2-G03V31_TASK_SPEC.md
startup_records/05_REQUIRED_CHECK_MANIFEST_P2-G03V31.md
```

创建分支：

```text
task/pangu2/pb-s0/p2-g03v31-governance-baseline
```

将 `repository_payload/` 对应文件复制到仓库相同路径。不得修改Forbidden Paths。不得修改Workflow、脚本或锁文件。

完成所有Required Tests，记录命令、退出码、日志和报告。创建Draft PR，PR描述绑定Task Spec、风险、测试、证据、Merge Base和Current Head。

首次审核：

```text
Previous Reviewed Head SHA: NONE
Review Range: Merge Base SHA → Current Head SHA
```

输出执行结果和审核提示词。不得merge或deploy。
