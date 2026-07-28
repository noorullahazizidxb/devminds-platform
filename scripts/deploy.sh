#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_MODE="${1:-local}"
case "$ENV_MODE" in
  local|production) ;;
  *)
    echo "Usage: $0 [local|production]" >&2
    exit 1
    ;;
esac

SOURCE=".env.local"
if [ "$ENV_MODE" = "production" ]; then
  SOURCE=".env.production"
fi

if [ ! -f "$SOURCE" ]; then
  echo "Missing $SOURCE — create it from the repo template before deploying." >&2
  exit 1
fi

echo "==> Using $SOURCE → .env ($ENV_MODE)"
cp "$SOURCE" .env

COMPOSE=(docker compose -f docker-compose.yml)
if [ "$ENV_MODE" = "local" ]; then
  COMPOSE+=(-f docker-compose.local.yml)
  echo "==> Local mode: apps on IP:ports (no Nginx)"
else
  echo "==> Production mode: Nginx + domains"
fi

"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up -d --build --remove-orphans
"${COMPOSE[@]}" ps

if [ "$ENV_MODE" = "local" ]; then
  cat <<'EOF'

Local URLs (same machine):
  Jobs UI:         http://127.0.0.1:3001
  Marketplace UI:  http://127.0.0.1:3002
  Jobs API:        http://127.0.0.1:4001/health
  Marketplace API: http://127.0.0.1:4002/api/health
Change LOCAL_PUBLIC_HOST in .env.local for LAN IP access, then redeploy.
EOF
fi
