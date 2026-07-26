# DevMinds Platform

Docker orchestration for the DevMinds landing site, Jobs portal, and Marketplace — shared MySQL, Redis, Elasticsearch, and Nginx TLS edge.

## Domains

| Host | Service |
|------|---------|
| `devminds.net` / `www.devminds.net` | Static landing (`nginx/www/landing`) |
| `jobs.devminds.net` | Jobs Next.js frontend + API (`/api`, `/socket.io`, `/uploads`, `/health`) |
| `marketplace.devminds.net` | Marketplace Next.js frontend + API (`/api`, `/socket.io`, `/uploads`) |

Point DNS (or local hosts) at the machine running this stack. Ports **80** and **443** are published by Nginx.

## Layout

```
devminds-platform/
├── docker-compose.yml
├── dockerfiles/          # App Dockerfiles (build contexts point at sibling repos)
├── mysql/init/           # Creates marketplace + job_portal databases
├── nginx/                # Edge proxy + landing + TLS certs
└── scripts/              # clean-docker / rebuild-fresh
```

Build contexts (relative to this folder):

- `../Jobs_Complete_Back-End-and-Front-End/job-service-back-end`
- `../Jobs_Complete_Back-End-and-Front-End/job-front-end`
- `../MarketPlace_Back_end__Front_End/MarketPlace-Back-End-Node-Parisma`
- `../MarketPlace_Back_end__Front_End/marketplace-Front-end`

## Quick start

1. Ensure Docker Desktop (or Docker Engine + Compose v2) is running.
2. Copy `.env.example` → `.env` if needed (a working `.env` is already present for local defaults).
3. Confirm sibling app repos exist at the paths above.
4. From this directory:

```powershell
docker compose up -d --build
```

5. Open:

- https://devminds.net (or http://localhost with `Host` header / hosts file)
- https://jobs.devminds.net
- https://marketplace.devminds.net

Self-signed certificates live in `nginx/certs/`. Browsers will warn until you install a real cert (e.g. Let’s Encrypt).

### Local hosts (optional)

```text
127.0.0.1  devminds.net www.devminds.net jobs.devminds.net marketplace.devminds.net
```

## Rebuild from scratch

Removes containers **and volumes**, rebuilds with no cache, then starts:

```powershell
.\scripts\rebuild-fresh.ps1
```

```bash
chmod +x scripts/*.sh
./scripts/rebuild-fresh.sh
```

Equivalent:

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

## Clean Docker

```powershell
.\scripts\clean-docker.ps1              # stop/remove containers
.\scripts\clean-docker.ps1 -Volumes     # also drop volumes
.\scripts\clean-docker.ps1 -Images      # remove project images
.\scripts\clean-docker.ps1 -Volumes -Images -Prune
```

```bash
./scripts/clean-docker.sh
./scripts/clean-docker.sh --volumes
./scripts/clean-docker.sh --images
./scripts/clean-docker.sh --volumes --images --prune
```

## Health endpoints

| URL | Expected |
|-----|----------|
| `https://devminds.net/health` | `ok` (landing) |
| `https://jobs.devminds.net/health` | Proxied to jobs-backend `:4000/health` |
| `https://marketplace.devminds.net/health` | Proxied to marketplace-backend `:4000/health` |

Also useful:

```bash
docker compose ps
docker compose logs -f jobs-backend marketplace-backend nginx
```

## Services

| Service | Image / build | Notes |
|---------|---------------|-------|
| `mysql` | `mysql:8.4` | Init script creates DBs; healthcheck enabled |
| `redis` | `redis:7.4-alpine` | AOF enabled |
| `elasticsearch` | `8.15.3` | Single-node, security off, 512m heap |
| `jobs-backend` | Dockerfile | Migrate + optional seed/reindex |
| `jobs-worker` | Same image | `node ./src/queue/imageProcessor.js` |
| `jobs-frontend` | Next.js | Bakes `NEXT_PUBLIC_API_BASE=https://jobs.devminds.net` |
| `marketplace-backend` | Dockerfile | Seeds when `RUN_SEEDS=true` (default) |
| `marketplace-frontend` | Next.js | Bakes marketplace public + internal `API_BASE` |
| `nginx` | `1.27-alpine` | HTTP + HTTPS for all domains |

## Environment notes

- `MYSQL_ROOT_PASSWORD` / app passwords: special characters in `DATABASE_URL_*` must be URL-encoded (`@` → `%40`).
- Frontend `NEXT_PUBLIC_*` values are **build args** — rebuild frontends after changing public URLs.
- Set `RUN_SEEDS=true` / `RUN_ES_REINDEX=true` as needed for first boot.

## TLS

Development certs:

```powershell
# regenerated into nginx/certs/fullchain.pem + privkey.pem
openssl req -x509 -nodes -newkey rsa:2048 -days 825 `
  -keyout nginx/certs/privkey.pem `
  -out nginx/certs/fullchain.pem `
  -subj "/CN=devminds.net" `
  -addext "subjectAltName=DNS:devminds.net,DNS:www.devminds.net,DNS:jobs.devminds.net,DNS:marketplace.devminds.net"
```

Replace with Let’s Encrypt (or other) certs for production; keep the same filenames or update `nginx/conf.d/*.conf`.