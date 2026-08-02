# PANGU2 — Staging Rollback Runbook

- **Environment:** BSC Testnet (Chain ID: 97)
- **Version:** 1.0.0
- **Last Updated:** 2026-08-02

## 1. When to Roll Back

### Immediate Rollback (P0 — Execute Immediately)
- [ ] Contract deployment introduces critical vulnerability
- [ ] Data corruption detected in database (unexplained balance changes)
- [ ] API returns incorrect financial data (wrong amounts, wrong tax rates)
- [ ] Private key or secret leaked to logs or public storage

### Planned Rollback (P1 — Schedule within 1 hour)
- [ ] Breaking API change that DApp cannot consume
- [ ] Indexer/Chain Worker stopped and cannot restart
- [ ] Performance degradation > 10x normal
- [ ] Multiple smoke test failures

### Do NOT Roll Back For
- [ ] Non-breaking UI changes
- [ ] Mock data discrepancies
- [ ] Single-job transient failures (retry first)
- [ ] Cosmetic issues

## 2. Pre-Rollback Checklist

Before initiating rollback, collect evidence:
```bash
# 1. Record current state
git log --oneline -5 > rollback-evidence/git-log.txt
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml ps > rollback-evidence/status.txt
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml logs --tail=200 > rollback-evidence/logs.txt

# 2. Dump affected database tables
docker compose exec -T postgres pg_dump -U pangu2 -d pangu2_staging \
  -t chain_raw_events -t transaction_projections -t admin_audit_logs \
  --data-only > rollback-evidence/db-dump.sql

# 3. Record last healthy block
curl -s http://localhost:8080/api/v1/projects/pangu2/system-status | jq '.data' > rollback-evidence/system-status.json
```

## 3. Rollback Procedures

### 3.1 Smart Contract Rollback

> ⚠ Smart contracts are immutable. "Rollback" means deploying a fixed version and updating configs. The old contract remains on-chain.

```bash
# Step 1: Deploy fixed contract
forge script script/DeployPangu2.s.sol \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast -vvv

# Step 2: Record new address
echo "NEW_ADDRESS=0x..." >> infra/staging/.env

# Step 3: Update backend config
# Edit backend/.env with new contract address

# Step 4: Restart backend
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml restart php

# Step 5: Verify
curl -s http://localhost:8080/api/v1/projects/pangu2/contracts | jq '.data'

# Step 6: Notify team and update DEPLOYMENT_MANIFEST.md
```

### 3.2 Backend Rollback (Git-based)

```bash
# Step 1: Stop backend
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml stop php queue scheduler

# Step 2: Revert to previous commit
cd backend
git log --oneline -5  # Find the last known-good commit
git revert <bad-commit-hash> --no-edit   # Revert in-place, or:
# git checkout <last-good-commit-hash>    # Hard reset (lose changes)

# Step 3: Run migrations if needed
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml run --rm php php artisan migrate:rollback
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml run --rm php php artisan migrate

# Step 4: Restart
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml start php queue scheduler

# Step 5: Smoke test
curl -s http://localhost:8080/up
curl -s http://localhost:8080/api/v1/projects/pangu2/config | jq '.data.chain_id'
```

### 3.3 Database Rollback

```bash
# Step 1: Stop all app services
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml stop php queue scheduler

# Step 2: Restore from backup
# (Assuming nightly pg_dump in infra/staging/backups/)
docker compose exec -T postgres psql -U pangu2 -d pangu2_staging \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker compose exec -T postgres psql -U pangu2 -d pangu2_staging \
  < infra/staging/backups/dump-YYYY-MM-DD.sql

# Step 3: Re-run migrations to current version
docker compose run --rm php php artisan migrate

# Step 4: Restart
docker compose start php queue scheduler
```

### 3.4 Chain Worker Rollback

```bash
# Step 1: Stop worker
cd services/chain-worker
pm2 stop pangu2-chain-worker  # or: kill $(pgrep -f "event-scanner")

# Step 2: Reset cursor to known-good block
docker compose exec -T postgres psql -U pangu2 -d pangu2_staging \
  -c "UPDATE chain_cursors SET last_scanned_block = <SAFE_BLOCK>, status = 'HEALTHY';"

# Step 3: Clear raw events from reorged blocks if needed
docker compose exec -T postgres psql -U pangu2 -d pangu2_staging \
  -c "DELETE FROM chain_raw_events WHERE block_number >= <REORG_BLOCK>;"

# Step 4: Restart worker
pm2 restart pangu2-chain-worker

# Step 5: Verify it's catching up
docker compose exec -T postgres psql -U pangu2 -d pangu2_staging \
  -c "SELECT * FROM chain_cursors WHERE stream = 'TRADE_EVENTS';"
```

### 3.5 Full Environment Teardown + Redeploy

```bash
# Step 1: Full stop + volume wipe
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml down -v

# Step 2: Rebuild
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml build --no-cache

# Step 3: Start fresh
docker compose -f docker-compose.yml -f infra/staging/docker-compose.staging.yml up -d

# Step 4: Migrate + seed
docker compose exec php php artisan migrate:fresh --seed

# Step 5: Full smoke test (see SMOKE_TEST_CHECKLIST.md)
```

## 4. Post-Rollback Verification

After any rollback, run the minimum verification set:

```bash
# 1. Health check
curl -s http://localhost:8080/up | jq '.status'

# 2. Chain ID correct
curl -s http://localhost:8080/api/v1/projects/pangu2/config | jq '.data.chain_id'
# Expected: 97

# 3. Contracts visible
curl -s http://localhost:8080/api/v1/projects/pangu2/contracts | jq '.data | length'
# Expected: > 0

# 4. Admin login works
curl -s -X POST http://localhost:8080/admin-api/v1/projects/pangu2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@pangu2.io","password":"test"}'

# 5. Jobs alive
curl -s http://localhost:8080/admin-api/v1/projects/pangu2/jobs \
  -H "Authorization: Bearer TBD"
```

## 5. Communication Template

After rollback (Slack/Teams):
```
⚠ PANGU2 Staging rollback executed
- Environment: BSC Testnet
- Trigger: <reason>
- Time: <timestamp>
- Previous commit: <hash>
- Rollback to: <hash>
- Rollback type: <smart-contract / backend / database / full>
- Duration: <N> minutes
- Post-rollback smoke: <PASS/FAIL>
- Evidence: docs/evidence/PB-S6/P2-I05/rollback-evidence/
```

## 6. Rollback Log

| Date | Trigger | Type | From | To | Duration | Smoke |
|---|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD |

---

**This runbook must be tested in staging before any production deployment.**
