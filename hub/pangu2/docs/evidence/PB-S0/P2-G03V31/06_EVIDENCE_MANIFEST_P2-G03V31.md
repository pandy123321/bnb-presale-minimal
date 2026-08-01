# Evidence Manifest — P2-G03V31

```text
Manifest ID: P2-G03V31-EVIDENCE-1.0
Status: TEMPLATE_READY
Task Start Base SHA: c8eaedbc47205194c518f2ff6a1415e3ff5abe16
Current Head SHA: <TO_BE_FIXED_AFTER_COMMIT>
Spec SHA: f6536f2ab38052a63090edff7e234f11c97d0d69689692de288829aa2d9e4d4e
Ruleset SHA: 91f2e06e36f122869a6720aab655bad1e1bcbda6cc8d64b8104036b1746d758e
```

每项必须填写：

```text
Evidence ID:
Type:
Command:
Working Directory:
Start Time:
End Time:
Exit Code:
Head SHA:
Log Path:
Report Path:
SHA-256:
Observed Count:
Failure Count:
Notes:
```

## Required Evidence

1. Workspace/branch/Base SHA preflight；
2. Duplicate Task/PR/Finding search；
3. File manifest；
4. UTF-8和单H1；
5. Internal links；
6. Parameter source uniqueness；
7. Forbidden Paths Diff；
8. Secret scan；
9. Old tier active-use scan；
10. Candidate SHA与提交后Git Blob/Head映射；
11. Draft PR信息；
12. Required Check Manifest结果。
