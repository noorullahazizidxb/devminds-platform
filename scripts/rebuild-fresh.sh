#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "WARNING: This deployment permanently deletes the Marketplace and Jobs MySQL databases." >&2
echo "==> Stopping the DevMinds stack..."
docker compose down --remove-orphans

echo "==> Removing only the DevMinds MySQL volume..."
mapfile -t mysql_volumes < <(docker volume ls --quiet \
  --filter "label=com.docker.compose.project=devminds-platform" \
  --filter "label=com.docker.compose.volume=mysql-data")
if ((${#mysql_volumes[@]})); then
  docker volume rm "${mysql_volumes[@]}"
fi

echo "==> Rebuilding all application images without cache..."
docker compose build --no-cache

echo "==> Starting the stack and recreating both databases..."
docker compose up -d --remove-orphans

echo "==> Fresh deployment started. Follow readiness with: docker compose ps"