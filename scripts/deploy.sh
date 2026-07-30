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
# Keep the template LF-clean too
sed $'s/\r$//' "$SOURCE" > "${SOURCE}.lf" && mv "${SOURCE}.lf" "$SOURCE"

# Always pin project name — never trust COMPOSE_PROJECT_NAME from a CRLF-tainted .env
COMPOSE=(docker compose --project-name "$PROJECT_NAME" --env-file .env -f docker-compose.yml)
if [ "$ENV_MODE" = "local" ]; then
  COMPOSE+=(-f docker-compose.local.yml)
  echo "==> Local mode: apps on IP:ports (no Nginx)"
else
  echo "==> Production mode: Nginx + domains (Nginx on 127.0.0.1:8080/8443)"
fi

"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up -d --build --remove-orphans

if [ "$ENV_MODE" = "local" ]; then
  # Stop leftover Nginx from a previous production run (profile-gated locally).
  docker compose --project-name "$PROJECT_NAME" -f docker-compose.yml stop nginx >/dev/null 2>&1 || true
  docker compose --project-name "$PROJECT_NAME" -f docker-compose.yml rm -f nginx >/dev/null 2>&1 || true
fi

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
else
  cat <<'EOF'

Production: DevMinds Nginx is on 127.0.0.1:8080 (HTTP) and 127.0.0.1:8443 (HTTPS).
If this VPS also hosts NewLinkAF (ticket.newlinkaf.com), start the edge gateway:

  cd gateway && docker compose up -d

See docs/GATEWAY.md for NewLinkAF port mapping (9080/9443) and routing details.
EOF
fi
