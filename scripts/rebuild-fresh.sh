#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Bringing stack down (with volumes)..."
docker compose down -v --remove-orphans

echo "==> Building images (--no-cache)..."
docker compose build --no-cache

echo "==> Starting stack..."
docker compose up -d

echo "==> Rebuild-fresh complete. Check: docker compose ps"