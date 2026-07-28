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
fi

echo "WARNING: This deployment permanently deletes the Marketplace and Jobs MySQL databases." >&2
echo "==> Stopping the DevMinds stack..."
"${COMPOSE[@]}" down --remove-orphans

echo "==> Removing only the DevMinds MySQL volume..."
mapfile -t mysql_volumes < <(docker volume ls --quiet \
  --filter "label=com.docker.compose.project=devminds-platform" \
  --filter "label=com.docker.compose.volume=mysql-data")
if ((${#mysql_volumes[@]})); then
  docker volume rm "${mysql_volumes[@]}"
fi

echo "==> Rebuilding all application images without cache..."
"${COMPOSE[@]}" build --no-cache

echo "==> Starting the stack and recreating both databases..."
"${COMPOSE[@]}" up -d --remove-orphans

echo "==> Fresh deployment started. Follow readiness with: ${COMPOSE[*]} ps"
