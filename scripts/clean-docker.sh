#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_NAME="devminds-platform"

BRANCH="$(git branch --show-current)"
echo "==> Pulling latest for branch '${BRANCH}'..."
git pull --ff-only origin "${BRANCH}"

VOLUMES=0
IMAGES=0
PRUNE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volumes|-v) VOLUMES=1 ;;
    --images) IMAGES=1 ;;
    --prune) PRUNE=1 ;;
    -h|--help)
      echo "Usage: $0 [--volumes] [--images] [--prune]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# Prefer a clean .env if present; still pin project name explicitly
ENV_ARGS=()
if [[ -f .env ]]; then
  sed $'s/\r$//' .env > .env.lf && mv .env.lf .env
  ENV_ARGS=(--env-file .env)
fi

COMPOSE=(docker compose --project-name "$PROJECT_NAME" "${ENV_ARGS[@]}" -f docker-compose.yml)

echo "==> Stopping compose stack..."
ARGS=(down --remove-orphans)
if [[ "$VOLUMES" -eq 1 ]]; then ARGS+=(-v); fi
if [[ "$IMAGES" -eq 1 ]]; then ARGS+=(--rmi local); fi
"${COMPOSE[@]}" "${ARGS[@]}" || true

# Force-stop any leftover DevMinds containers (wrong project name / orphaned)
mapfile -t DEV_CONTAINERS < <(docker ps -aq --filter "name=^/devminds-" || true)
if ((${#DEV_CONTAINERS[@]})); then
  docker stop "${DEV_CONTAINERS[@]}" >/dev/null || true
  docker rm -f "${DEV_CONTAINERS[@]}" >/dev/null || true
fi

if [[ "$PRUNE" -eq 1 ]]; then
  echo "==> Pruning unused Docker data..."
  docker system prune -f
  if [[ "$VOLUMES" -eq 1 ]]; then
    docker volume prune -f
  fi
fi

echo "==> Clean complete."
