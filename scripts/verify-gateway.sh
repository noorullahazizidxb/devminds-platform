#!/usr/bin/env bash
# Quick VPS verification for edge gateway + both app stacks.
set -euo pipefail

echo "==> public-proxy network"
docker network inspect public-proxy --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "MISSING — run: docker network create public-proxy"

echo "==> gateway-health"
curl -fsS http://127.0.0.1/gateway-health; echo

echo "==> DevMinds via edge (HTTP)"
curl -sI -H 'Host: jobs.devminds.net' --max-time 10 http://127.0.0.1/ | head -n 5 || true

echo "==> DevMinds direct (HTTP :8080)"
curl -sI -H 'Host: jobs.devminds.net' --max-time 10 http://127.0.0.1:8080/ | head -n 5 || true

echo "==> DevMinds HTTPS"
curl -skI --max-time 15 https://jobs.devminds.net/health | head -n 8 || true

echo "==> Marketplace HTTPS"
curl -skI --max-time 15 https://marketplace.devminds.net/ | head -n 8 || true

echo "==> NewLinkAF via edge (HTTP)"
curl -sI -H 'Host: ticket.newlinkaf.com' --max-time 10 http://127.0.0.1/ | head -n 5 || true

echo "==> Landing HTTPS"
curl -skI --max-time 15 https://devminds.net/ | head -n 8 || true

echo "==> NewLinkAF direct :9080"
curl -sI -H 'Host: ticket.newlinkaf.com' --max-time 10 http://127.0.0.1:9080/ | head -n 5 || true

echo "==> NewLinkAF HTTPS"
curl -skI --max-time 15 https://ticket.newlinkaf.com/ | head -n 8 || true

echo "==> Cert issuer (jobs)"
echo | openssl s_client -connect jobs.devminds.net:443 -servername jobs.devminds.net 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates 2>/dev/null || echo "(openssl check skipped/failed)"
