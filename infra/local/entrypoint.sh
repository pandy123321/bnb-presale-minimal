#!/bin/sh
# ═══════════════════════════════════════════
# PANGU2 — Node Service Entrypoint
# Handles dependency install for Docker services.
# ═══════════════════════════════════════════

set -e

SERVICE_DIR="$1"
shift

if [ -z "$SERVICE_DIR" ]; then
  echo "Usage: entrypoint.sh <service-dir> [command...]"
  exit 1
fi

cd "/workspace/$SERVICE_DIR"

if [ ! -d "node_modules" ]; then
  echo "=== Installing dependencies for $SERVICE_DIR ==="
  pnpm install --prefer-offline
fi

echo "=== Starting $SERVICE_DIR ==="

if [ $# -eq 0 ]; then
  exec pnpm dev
else
  exec "$@"
fi
