#!/usr/bin/env bash
# Issue (or renew) Let's Encrypt certs for DevMinds domains and install them
# into nginx/certs/ for devminds-nginx (SNI-terminated behind the edge gateway).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EMAIL="${CERTBOT_EMAIL:-admin@devminds.net}"
WEBROOT="$(pwd)/nginx/www/certbot"
LIVE_DIR="/etc/letsencrypt/live/devminds.net"

mkdir -p "$WEBROOT/.well-known/acme-challenge" nginx/certs

echo "==> Ensuring edge gateway + DevMinds nginx are up (ACME HTTP-01 via :80)..."
unset COMPOSE_PROJECT_NAME
docker network create public-proxy 2>/dev/null || true
docker compose --project-name edge-gateway -f gateway/docker-compose.yml --project-directory gateway up -d
docker compose --project-name devminds-platform --env-file .env up -d nginx

echo "==> Requesting certificate (webroot)..."
sudo certbot certonly --webroot \
  -w "$WEBROOT" \
  -d devminds.net -d www.devminds.net \
  -d jobs.devminds.net \
  -d marketplace.devminds.net -d marketplace.devminds.com \
  --email "$EMAIL" --agree-tos --no-eff-email --non-interactive

if [[ ! -f "${LIVE_DIR}/fullchain.pem" || ! -f "${LIVE_DIR}/privkey.pem" ]]; then
  echo "ERROR: expected certs missing under ${LIVE_DIR}" >&2
  exit 1
fi

echo "==> Installing into nginx/certs/..."
sudo cp "${LIVE_DIR}/fullchain.pem" nginx/certs/fullchain.pem
sudo cp "${LIVE_DIR}/privkey.pem" nginx/certs/privkey.pem
sudo chown "$USER:$USER" nginx/certs/fullchain.pem nginx/certs/privkey.pem

echo "==> Reloading DevMinds nginx..."
docker compose --project-name devminds-platform exec -T nginx nginx -s reload

echo "==> Certificate subject / issuer:"
docker run --rm -v "$(pwd)/nginx/certs:/certs:ro" alpine/openssl \
  x509 -in /certs/fullchain.pem -noout -subject -issuer -dates 2>/dev/null \
  || openssl x509 -in nginx/certs/fullchain.pem -noout -subject -issuer -dates

echo "==> Done. Verify: curl -skI https://jobs.devminds.net/health"
