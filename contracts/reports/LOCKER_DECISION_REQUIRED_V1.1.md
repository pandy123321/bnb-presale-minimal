# Locker Decision Requirement V1.1

Formal deployment is intentionally blocked until all four values are explicitly supplied:

```text
LOCK_MODE
LOCK_DURATION
LOCK_RELEASE_RECIPIENT
LOCK_DECISION_ID
```

Validation rules:

- `LOCK_DECISION_ID` must be non-empty and start with `DR-`.
- `PERMANENT` requires `LOCK_DURATION=0`.
- `FIXED_DURATION` requires `LOCK_DURATION>0`.
- `LOCK_RELEASE_RECIPIENT` must be non-zero and is additionally checked against the deployer by the deployment script.
- No seven-day, 365-day or permanent default is present in the deployment script.

`TEST_FIXTURE_LOCK_DURATION = 7 days` exists only in tests and is not a frozen business parameter.
