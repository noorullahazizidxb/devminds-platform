# External Nginx Edge Gateway

On the VPS, **DevMinds** and **NewLinkAF** (`/opt/newlinkaf.com`) each have their own Nginx. Both previously wanted host ports **80** and **443**. This gateway owns those public ports and routes by hostname to the two internal Nginx instances **over the shared Docker network `public-proxy`**.

```text
Internet
   │
   ▼
edge-gateway-nginx  (:80 / :443)     ← gateway/docker-compose.yml
   │
   ├── Host: ticket.newlinkaf.com
   │         → newlinkaf-nginx:80 (HTTP) / :443 (HTTPS SNI)
   │
   └── Host: *.devminds.net
             → devminds-internal-nginx:80 (HTTP) / :443 (HTTPS SNI)
```

**Why not `host.docker.internal:8080`?** On Linux Docker, `host.docker.internal` resolves to the bridge gateway IP. Services bound only to `127.0.0.1:8080` are **not** reachable on that IP — proxies hang and return **504**. Use Docker DNS aliases on `public-proxy` instead.

- **HTTP (80):** reverse-proxy by `Host` header (ACME + redirects stay on each app).
- **HTTPS (443):** SNI passthrough — each app keeps its own TLS certificates.

## Port map

| Listener | Who binds it | Notes |
|----------|--------------|-------|
| `0.0.0.0:80` / `:443` | `edge-gateway-nginx` | Public edge |
| `127.0.0.1:8080` / `:8443` | `devminds-nginx` | Host debug only; edge uses Docker DNS |
| `127.0.0.1:9080` / `:9443` | `newlinkaf-nginx` | Host debug only; edge uses Docker DNS |

Shared network: `public-proxy` (create once: `docker network create public-proxy`).

Aliases:

- DevMinds → `devminds-internal-nginx`
- NewLinkAF → `newlinkaf-nginx`

## 1. Point NewLinkAF Nginx at localhost debug ports + public-proxy

In `/opt/newlinkaf.com` docker-compose nginx service:

```yaml
services:
  nginx:
    container_name: newlinkaf-nginx
    ports:
      - "127.0.0.1:9080:80"
      - "127.0.0.1:9443:443"
    volumes:
      - ${NGINX_CONF:-./docker/nginx.conf}:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - ./certbot-webroot:/var/www/certbot:ro
    networks:
      internal:
      public-proxy:
        aliases:
          - newlinkaf-nginx
```

Then recreate that stack:

```bash
docker network create public-proxy 2>/dev/null || true
cd /opt/newlinkaf.com
docker compose up -d
```

Confirm nothing else still binds public 80/443 except the edge gateway:

```bash
sudo ss -tlnp | grep -E ':80 |:443 '
```

## 2. Start DevMinds (internal Nginx on 8080/8443 + public-proxy)

```bash
cd /path/to/devminds-platform
./scripts/deploy.sh production
```

DevMinds Nginx publishes `127.0.0.1:8080:80` / `8443:443` and joins `public-proxy` as `devminds-internal-nginx`.

## 3. Start the external gateway

**Important:** if you previously `export COMPOSE_PROJECT_NAME=devminds-platform`, unset it first. That env var overrides `name: edge-gateway`.

```bash
cd /path/to/devminds-platform/gateway
cp -n .env.example .env
unset COMPOSE_PROJECT_NAME
docker network create public-proxy 2>/dev/null || true
docker compose --project-name edge-gateway up -d
docker compose --project-name edge-gateway ps
curl -s http://127.0.0.1/gateway-health
# → gateway-ok
```

From repo root:

```bash
unset COMPOSE_PROJECT_NAME
docker compose -f gateway/docker-compose.yml --project-directory gateway --project-name edge-gateway up -d
```

If `edge-gateway-nginx` is `Restarting`, check logs (`docker logs edge-gateway-nginx`).

Common causes:

- **`load_module ... ngx_stream_module.so` failed** — official `nginx:*-alpine` builds stream into the binary; do not `load_module` those `.so` files (see `gateway/nginx/nginx.conf`).
- **Stale container name** — remove the old container: `docker rm -f edge-gateway-nginx`
- **Wrong Compose project** — `unset COMPOSE_PROJECT_NAME` and always use `--project-name edge-gateway`
- **504 Gateway Time-out** — edge cannot reach upstream; confirm both app nginx containers are on `public-proxy` (`docker network inspect public-proxy`)
- **HTTPS `Connection reset by peer` while HTTP works** — stream SNI uses `proxy_pass $variable`, which needs Docker DNS: `resolver 127.0.0.11` in the stream template. Recreate the gateway after pulling that fix.

## 4. Verify routing

```bash
# DevMinds (via edge)
curl -sI -H 'Host: jobs.devminds.net' http://127.0.0.1/
curl -skI https://jobs.devminds.net/health

# Direct to DevMinds nginx (bypass edge)
curl -sI -H 'Host: jobs.devminds.net' http://127.0.0.1:8080/

# NewLinkAF
curl -sI -H 'Host: ticket.newlinkaf.com' http://127.0.0.1:9080/
curl -skI https://ticket.newlinkaf.com/
```

## Custom upstreams

Edit `gateway/.env` (see `.env.example`):

```env
DEVMINDS_HTTP_UPSTREAM=devminds-internal-nginx:80
DEVMINDS_HTTPS_UPSTREAM=devminds-internal-nginx:443
NEWLINKAF_HTTP_UPSTREAM=newlinkaf-nginx:80
NEWLINKAF_HTTPS_UPSTREAM=newlinkaf-nginx:443
```

Then `docker compose --project-name edge-gateway up -d` again in `gateway/`.

## TLS / Let’s Encrypt

Issue and renew certs **on each app** (webroot through the edge → app nginx ACME locations). The gateway does not terminate TLS for app domains; it forwards 443 by SNI.

DevMinds helper:

```bash
cd /opt/devminds/devminds-platform
chmod +x scripts/issue-ssl-devminds.sh
./scripts/issue-ssl-devminds.sh
```

That writes LE material into `nginx/certs/{fullchain,privkey}.pem` and reloads `devminds-nginx`.

NewLinkAF keeps `/etc/letsencrypt/live/ticket.newlinkaf.com/` (see `/opt/newlinkaf.com` scripts).

HTTP-01 ACME on port 80 still works: the gateway proxies `Host`-matched traffic to the correct internal Nginx, which serves `/.well-known/acme-challenge/`.

## Operations

```bash
cd gateway
unset COMPOSE_PROJECT_NAME
docker compose --project-name edge-gateway logs -f gateway-nginx
docker compose --project-name edge-gateway exec gateway-nginx nginx -t
docker compose --project-name edge-gateway exec gateway-nginx nginx -s reload
docker compose --project-name edge-gateway down    # stops gateway only; apps keep running on localhost ports
```

Bring-up order on a fresh VPS:

1. `docker network create public-proxy`
2. NewLinkAF (9080/9443 + public-proxy)
3. DevMinds (8080/8443 + public-proxy)
4. Gateway on `80`/`443`
