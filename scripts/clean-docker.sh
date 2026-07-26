#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

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

echo "==> Stopping compose stack..."
ARGS=(compose down --remove-orphans)
if [[ "$VOLUMES" -eq 1 ]]; then ARGS+=(-v); fi
if [[ "$IMAGES" -eq 1 ]]; then ARGS+=(--rmi local); fi
docker "${ARGS[@]}"

if [[ "$PRUNE" -eq 1 ]]; then
  echo "==> Pruning unused Docker data..."
  docker system prune -f
  if [[ "$VOLUMES" -eq 1 ]]; then
    docker volume prune -f
  fi
fi

echo "==> Clean complete."