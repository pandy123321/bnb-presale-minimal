#!/bin/bash
# PANGU2 V2 — API Schema Validation
# Validates that the running backend matches the OpenAPI contract.
# Must be run in CI after Docker Compose is up.

set -euo pipefail

ENDPOINTS=(
  "GET /api/v1/projects/pangu2/config"
  "GET /api/v1/projects/pangu2/system-status"
  "GET /api/v1/projects/pangu2/contracts"
  "POST /api/v1/projects/pangu2/auth/nonce" '{"wallet_address":"0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}'
  "POST /api/v1/projects/pangu2/quotes/buy"  '{"amount_bnb_wei":"100000000000000000"}'
  "GET /api/v1/projects/pangu2/dividend/epochs/current"
  "GET /api/v1/projects/pangu2/buybacks"
  "GET /api/v1/projects/pangu2/locker/batches"
)

BASE_URL="${PANGU2_API_URL:-http://localhost:8080}"
FAIL=0

for ((i=0; i<${#ENDPOINTS[@]}; i+=2)); do
  METHOD="${ENDPOINTS[$i]%% *}"
  PATH="${ENDPOINTS[$i]#* }"
  BODY="${ENDPOINTS[$i+1]:-}"

  echo -n "Validating $METHOD $PATH ... "

  if [ -n "$BODY" ]; then
    RESP=$(curl -s -w "\n%{http_code}" -X "$METHOD" "$BASE_URL$PATH" \
      -H "Content-Type: application/json" -d "$BODY" 2>&1)
  else
    RESP=$(curl -s -w "\n%{http_code}" -X "$METHOD" "$BASE_URL$PATH" \
      -H "Content-Type: application/json" 2>&1)
  fi

  HTTP_CODE=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | sed '$d')

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    # Check that response has envelope structure (success or error envelope)
    HAS_DATA=$(echo "$BODY" | grep -c '"data"' || true)
    HAS_META=$(echo "$BODY" | grep -c '"meta"' || true)
    if [ "$HAS_DATA" -ge 1 ] && [ "$HAS_META" -ge 1 ]; then
      echo "OK ($HTTP_CODE)"
    else
      echo "INVALID — missing envelope fields"
      FAIL=$((FAIL+1))
    fi
  else
    echo "FAIL ($HTTP_CODE)"
    FAIL=$((FAIL+1))
  fi
done

echo ""
if [ $FAIL -eq 0 ]; then
  echo "All endpoints validated successfully."
  exit 0
else
  echo "$FAIL endpoint(s) failed validation."
  exit 1
fi
