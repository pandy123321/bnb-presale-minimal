# PANGU2 — Staging Monitoring & Alerting Checklist

- **Environment:** BSC Testnet (Chain ID: 97)
- **Monitoring cadence:** See intervals below

## 1. Critical Alerts (P0 — Immediate Response)

| # | Alert | Check Method | Interval | Threshold | Escalation |
|---|---|---|---|---|---|
| 1 | Backend health check failure | `GET /up` — HTTP 200 | 30s | 2 consecutive failures | Pager |
| 2 | RPC unreachable | `eth_chainId` on primary + backup | 60s | Both unreachable for 2 min | Pager |
| 3 | Database connection lost | `pg_isready` on postgres container | 30s | 1 failure | Pager |
| 4 | Redis connection lost | `redis-cli PING` | 30s | 1 failure | Pager |
| 5 | Contract address mismatch | Compare `/contracts` vs DEPLOYMENT_MANIFEST.md | 10min | Any mismatch | Slack + Pager |

## 2. Data Integrity Alerts (P1 — Response within 15 min)

| # | Alert | Check Method | Interval | Threshold | Escalation |
|---|---|---|---|---|---|
| 6 | Block lag exceeds threshold | `/system-status` → `block_lag` | 60s | > 20 blocks for 5 min | Slack |
| 7 | Chain Worker scanner stopped | `/admin/jobs` → chain-sync status | 60s | Not RUNNING or HEALTHY | Slack |
| 8 | Queue worker backlog | Redis `LLEN queues:default` | 60s | > 100 jobs pending for 10 min | Slack |
| 9 | Open anomalies | `/admin/dashboard` → `open_anomalies` | 5min | > 0 | Slack |
| 10 | Database disk usage | `df -h /var/lib/postgresql/data` | 10min | > 80% | Slack |
| 11 | Reorg detected | `chain_raw_events` rows with `status=REORGED` in last 10 min | 60s | > 0 | Slack |
| 12 | Failed transactions spike | Count of `transaction_projections.status=failed` in last 1h | 5min | > 5% of total | Slack |

## 3. Performance Alerts (P2 — Review within 1 hour)

| # | Alert | Check Method | Interval | Threshold | Escalation |
|---|---|---|---|---|---|
| 13 | API response time | `GET /api/v1/projects/pangu2/config` latency | 60s | p95 > 2s for 10 min | Slack |
| 14 | Quote response time | `POST /api/v1/projects/pangu2/quotes/buy` latency | 5min | p95 > 5s | Slack |
| 15 | Database slow queries | PostgreSQL `log_min_duration_statement` | — | > 1s | Log + Slack digest |
| 16 | Memory usage | `docker stats` on php container | 5min | > 80% of limit | Slack |
| 17 | CPU usage | `docker stats` on php container | 5min | sustained > 70% for 10 min | Slack |

## 4. Security Alerts

| # | Alert | Check Method | Interval | Threshold | Escalation |
|---|---|---|---|---|---|
| 18 | Unauthorized admin access | `admin_audit_logs` with `result=FAILED` for auth | 5min | > 5 in 10 min | Slack + Pager |
| 19 | Job retry without idempotency | `admin_audit_logs.action=JOB_RETRY_QUEUED` with null `idempotency_key` | 10min | > 0 | Slack |
| 20 | External contract operation | `contract_event_logs.source=EXTERNAL_OPERATION` | 5min | > 0 | Slack |
| 21 | `allow_mainnet_writes` enabled | `GET /config` → check environment | 10min | `true` on testnet | Pager |

## 5. Dashboard & Visualization

### Grafana / Prometheus Dashboard Panels (Recommended)

| Panel | Data Source | Metric |
|---|---|---|
| Block Lag Trend | `/system-status` API | `block_lag` over time |
| Transaction Throughput | `transaction_projections` | `COUNT(*)` grouped by 5min |
| Buy/Sell Ratio | `transaction_projections` | `type` distribution |
| Token Supply Circulating | Contract `totalSupply()` | — |
| Support Pool BNB Balance | Contract `supportPoolBalance()` | — |
| Active Wallet Count | `transaction_projections` | `COUNT(DISTINCT from_address)` |
| Queue Depth | Redis | `LLEN queues:default` |
| DB Size | PostgreSQL | `pg_database_size()` |
| API Latency | Nginx access log | P50/P95/P99 |
| Error Rate | Nginx access log | `status >= 500` rate |

## 6. Health Check Script

```bash
#!/bin/bash
# pangu2-health-check.sh — run via cron every 30s
BASE="http://localhost:8080"

# Backend alive
if ! curl -sf "$BASE/up" > /dev/null; then
  echo "[CRITICAL] Backend health check failed"
fi

# RPC connected
CHAIN=$(curl -sf "$BASE/api/v1/projects/pangu2/config" | jq -r '.data.chain_id')
if [ "$CHAIN" != "97" ]; then
  echo "[CRITICAL] Wrong chain ID: $CHAIN"
fi

# Block lag
LAG=$(curl -sf "$BASE/api/v1/projects/pangu2/system-status" | jq -r '.data.block_lag')
if [ "$LAG" -gt 20 ]; then
  echo "[WARNING] Block lag: $LAG"
fi

# Anomalies
ANOM=$(curl -sf "$BASE/admin-api/v1/projects/pangu2/dashboard" \
  -H "Authorization: Bearer TBD" | jq -r '.data.open_anomalies')
if [ "$ANOM" -gt 0 ]; then
  echo "[WARNING] Open anomalies: $ANOM"
fi
```

## 7. Log Forwarding

| Log Source | Destination | Format |
|---|---|---|
| Nginx access log | ELK / Loki | JSON |
| PHP error log | ELK / Loki | — |
| Laravel application log | ELK / Loki | Monolog JSON |
| PostgreSQL slow query log | ELK / pgBadger | CSV |
| Chain Worker stdout | ELK / Loki | Plain text |
| `admin_audit_logs` table | Separate audit log store | Native |
| Docker container logs | Docker logging driver → ELK | — |

## 8. Uptime & SLA Targets

| Metric | Target |
|---|---|
| Backend API uptime | 99.5% (monthly) |
| Chain Worker uptime | 99% (monthly) |
| Event indexing latency | < 5 blocks behind (P95) |
| Alert response (P0) | < 15 minutes |
| Alert response (P1) | < 1 hour |

---

**This checklist must be updated after monitoring infrastructure is set up with actual endpoint URLs and credentials.**
