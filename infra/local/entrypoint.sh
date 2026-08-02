#!/bin/sh
# ═══════════════════════════════════════════
# PANGU2 — Node Service Entrypoint
# Handles first-run dependency install and
# workspace:* protocol resolution.
# ═══════════════════════════════════════════

set -e

SERVICE_DIR="$1"
shift

if [ -z "$SERVICE_DIR" ]; then
  echo "Usage: entrypoint.sh <service-dir> [command...]"
  exit 1
fi

cd "/workspace/$SERVICE_DIR"

# Check if we need to install dependencies
if [ ! -d "node_modules" ]; then
  echo "=== Installing dependencies for $SERVICE_DIR ==="

  # Create a temp package.json that replaces workspace:* with file: references
  if grep -q "workspace:\*" package.json 2>/dev/null; then
    echo "=== Resolving workspace:* dependencies ==="
    # Create symlink for local api-types package
    mkdir -p node_modules/.cache
    # The workspace:* deps will fail with pnpm if not in a workspace.
    # We use --config.ignore-workspace-root-check and install from local paths.
    # Simpler: replace workspace:* with file: in a temp copy
    sed 's/"workspace:\*"/"file:..\/..\/packages\/api-types"/g' package.json > package.tmp.json
    mv package.tmp.json package.json
  fi

  pnpm install --frozen-lockfile=false --prefer-offline 2>/dev/null || \
  pnpm install --prefer-offline
fi

echo "=== Starting $SERVICE_DIR ==="

if [ $# -eq 0 ]; then
  exec pnpm dev
else
  exec "$@"
fi
