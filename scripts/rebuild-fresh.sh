#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_NAME="devminds-platform"

BRANCH="$(git branch --show-current)"
echo "==> Pulling latest for branch '${BRANCH}'..."
git pull --ff-only origin "${BRANCH}"

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
# Strip Windows CRLF so Compose never sees values like "devminds-platform\r"
sed $'s/\r$//' "$SOURCE" > .env
sed $'s/\r$//' "$SOURCE" > "${SOURCE}.lf" && mv "${SOURCE}.lf" "$SOURCE"

# Always pin project name — never trust COMPOSE_PROJECT_NAME from a CRLF-tainted .env
COMPOSE=(docker compose --project-name "$PROJECT_NAME" --env-file .env -f docker-compose.yml)
if [ "$ENV_MODE" = "local" ]; then
  COMPOSE+=(-f docker-compose.local.yml)
fi

echo "WARNING: This deployment permanently deletes the Marketplace and Jobs MySQL databases." >&2

echo "==> Stopping DevMinds containers (by name, so a bad project name cannot leave MySQL running)..."
mapfile -t DEV_CONTAINERS < <(docker ps -aq --filter "name=^/devminds-" || true)
if ((${#DEV_CONTAINERS[@]})); then
  docker stop "${DEV_CONTAINERS[@]}" >/dev/null
  docker rm -f "${DEV_CONTAINERS[@]}" >/dev/null
fi

echo "==> Stopping the DevMinds Compose project..."
"${COMPOSE[@]}" down --remove-orphans || true
# Also tear down a stale CRLF project name if it still exists
docker compose --project-name $'devminds-platform\r' down --remove-orphans >/dev/null 2>&1 || true

echo "==> Removing only the DevMinds MySQL volume..."
# Always try the canonical Compose name first (works even if labels are missing).
mapfile -t mysql_volumes < <({
  echo "${PROJECT_NAME}_mysql-data"
  docker volume ls --quiet \
    --filter "label=com.docker.compose.project=${PROJECT_NAME}" \
    --filter "label=com.docker.compose.volume=mysql-data" || true
  docker volume ls --quiet | grep -E 'devminds.*mysql-data|mysql-data' | grep -i devminds || true
} | awk 'NF && !seen[$0]++')
removed_any=0
for vol in "${mysql_volumes[@]}"; do
  [[ -n "${vol}" ]] || continue
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "    removing volume: $vol"
    docker volume rm "$vol"
    removed_any=1
  fi
done
if [[ "$removed_any" -eq 0 ]]; then
  echo "    no mysql-data volume found (already removed — continuing)"
fi

echo "==> Rebuilding all application images without cache..."
"${COMPOSE[@]}" build --no-cache

echo "==> Starting the stack and recreating both databases..."
"${COMPOSE[@]}" up -d --remove-orphans

echo "==> Fresh deployment started. Follow readiness with: ${COMPOSE[*]} ps"
