# External Nginx Edge Gateway

On the VPS, **DevMinds** and **NewLinkAF** (`/opt/newlinkaf.com`) each have their own Nginx. Both previously wanted host ports **80** and **443**. This gateway owns those public ports and routes by hostname to the two internal Nginx instances.

```text
Internet
   │
   ▼
edge-gateway-nginx  (:80 / :443)     ← gateway/docker-compose.yml
   │
   ├── Host: ticket.newlinkaf.com
   │         → 127.0.0.1:9080 (HTTP) / :9443 (HTTPS)   NewLinkAF Nginx
   │
   └── Host: *.devminds.net / marketplace.devminds.com
             (incl. noorullah-azizi-ceo.devminds.net)
             → 127.0.0.1:8080 (HTTP) / :8443 (HTTPS)   DevMinds Nginx
```

Hostnames are an **explicit list** in `gateway/nginx/templates/` (not a true DNS wildcard). Add new DevMinds hosts to both HTTP `server_name` and the SNI map, then recreate the gateway container so envsubst regenerates config.

- **HTTP (80):** reverse-proxy by `Host` header (ACME + redirects stay on each app).
- **HTTPS (443):** SNI passthrough — each app keeps its own TLS certificates.

### Portfolio host (`noorullah-azizi-ceo.devminds.net`)

Registered on the edge → DevMinds Nginx. Path routing inside `nginx/conf.d/noorullah-azizi-ceo.conf`:

| Path | Upstream container |
|------|--------------------|
| `/` | `noorullah-portfolio-elite:8080` |
| `/v1/` | `noorullah-portfolio-v1:8080` |
| `/v2/` | `noorullah-portfolio-v2:8080` |

Deploy containers from the `noorullah-portfolio-deployment` package onto `devminds-net`, then expand the Let’s Encrypt SAN (see `DEPLOY-VPS.md`).

## Port map

| Listener | Who binds it | Notes |
|----------|--------------|-------|
| `0.0.0.0:80` / `:443` | `edge-gateway-nginx` | Public edge |
| `127.0.0.1:8080` / `:8443` | `devminds-nginx` | Internal only (root `docker-compose.yml`) |
| `127.0.0.1:9080` / `:9443` | NewLinkAF nginx | You must set this in `/opt/newlinkaf.com` |

## 1. Point NewLinkAF Nginx at localhost ports

In `/opt/newlinkaf.com` docker-compose (or equivalent), change the Nginx service from publishing public 80/443 to localhost-only:

```yaml
services:
  nginx:  # use the actual service name in that project
    ports:
      - "127.0.0.1:9080:80"
      - "127.0.0.1:9443:443"
```

Then recreate that stack:

```bash
cd /opt/newlinkaf.com
docker compose up -d
```

Confirm nothing else still binds public 80/443:

```bash
sudo ss -tlnp | grep -E ':80|:443'
```

## 2. Start DevMinds (internal Nginx on 8080/8443)

```bash
cd /path/to/devminds-platform
./scripts/deploy.sh production
```

DevMinds Nginx already publishes `127.0.0.1:8080:80` and `127.0.0.1:8443:443`.

## 3. Start the external gateway

```bash
cd /path/to/devminds-platform/gateway
cp -n .env.example .env   # optional; defaults are fine for the port map above
docker compose up -d
docker compose ps
curl -s -H 'Host: devminds.net' http://127.0.0.1/gateway-health
# → gateway-ok
```

From repo root:

```bash
docker compose -f gateway/docker-compose.yml --project-directory gateway up -d
```

## 4. Verify routing

```bash
# DevMinds
curl -sI -H 'Host: jobs.devminds.net' http://127.0.0.1/
curl -skI https://jobs.devminds.net/health

# NewLinkAF
curl -sI -H 'Host: ticket.newlinkaf.com' http://127.0.0.1/
curl -skI https://ticket.newlinkaf.com/
```

## Custom upstreams

Edit `gateway/.env` (see `.env.example`):

```env
DEVMINDS_HTTP_UPSTREAM=host.docker.internal:8080
DEVMINDS_HTTPS_UPSTREAM=host.docker.internal:8443
NEWLINKAF_HTTP_UPSTREAM=host.docker.internal:9080
NEWLINKAF_HTTPS_UPSTREAM=host.docker.internal:9443
```

Then `docker compose up -d` again in `gateway/`.

`host.docker.internal` is mapped to the Docker host via `extra_hosts: host.docker.internal:host-gateway`.

## TLS / Let’s Encrypt

Issue and renew certs **on each app** as before (webroot or standalone against each internal Nginx). The gateway does not terminate TLS for app domains; it forwards 443 by SNI.

HTTP-01 ACME on port 80 still works: the gateway proxies `Host`-matched traffic to the correct internal Nginx, which serves `/.well-known/acme-challenge/`.

## Operations

```bash
cd gateway
docker compose logs -f gateway-nginx
docker compose exec gateway-nginx nginx -t
docker compose exec gateway-nginx nginx -s reload
docker compose down    # stops gateway only; apps keep running on localhost ports
```

Bring-up order on a fresh VPS:

1. NewLinkAF on `9080`/`9443`
2. DevMinds on `8080`/`8443`
3. Gateway on `80`/`443`
