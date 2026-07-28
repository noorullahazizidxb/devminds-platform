# DevMinds Platform

Docker orchestration for the DevMinds landing site, Jobs portal, and Marketplace — shared MySQL, Redis, Elasticsearch, and Nginx TLS edge.

## Domains

| Host | Service |
|------|---------|
| `devminds.net` / `www.devminds.net` | Static landing (`nginx/www/landing`) |
| `jobs.devminds.net` | Jobs Next.js frontend + API (`/api`, `/socket.io`, `/uploads`, `/health`) |
| `marketplace.devminds.net` / `.com` | Marketplace Next.js frontend + API (`/api`, `/socket.io`, `/uploads`, `/health`) |

Point DNS (or local hosts) at the machine running this stack. Ports **80** and **443** are published by Nginx.

## Layout

```
devminds-platform/
├── .env.local            # Localhost IP:port template (tracked)
├── .env.production       # VPS domains template (tracked; ChangeMe* secrets)
├── .env                  # Active runtime file (gitignored; copied by deploy)
├── docker-compose.yml
├── docker-compose.local.yml  # Publishes :3001/:3002/:4001/:4002; skips Nginx
├── dockerfiles/          # App Dockerfiles (build contexts point at sibling repos)
├── mysql/init/           # Creates marketplace + job_portal databases
├── nginx/                # Edge proxy + landing + TLS certs + ACME webroot
└── scripts/              # deploy / rebuild-fresh / clean-docker
```

Build contexts (relative to this folder):

- `../Jobs_Complete_Back-End-and-Front-End/job-service-back-end`
- `../Jobs_Complete_Back-End-and-Front-End/job-front-end`
- `../MarketPlace_Back_end__Front_End/MarketPlace-Back-End-Node-Parisma`
- `../MarketPlace_Back_end__Front_End/marketplace-Front-end`

## Docs

| Guide | Path |
|-------|------|
| Localhost runbook | [docs/LOCALHOST.md](docs/LOCALHOST.md) |
| Ubuntu VPS + Let’s Encrypt | [docs/DEPLOY-VPS.md](docs/DEPLOY-VPS.md) |

## Quick start (localhost — IP + ports)

1. Ensure Docker Desktop (or Docker Engine + Compose v2) is running.
2. Confirm sibling app repos exist at the paths above.
3. From this directory:

```powershell
.\scripts\deploy.ps1
# copies .env.local → .env, uses docker-compose.local.yml (no Nginx)
```

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

4. Open:

| App | URL |
|-----|-----|
| Jobs | http://127.0.0.1:3001 |
| Marketplace | http://127.0.0.1:3002 |
| Jobs API | http://127.0.0.1:4001/health |
| Marketplace API | http://127.0.0.1:4002/api/health |

Production VPS (domains + Nginx):

```bash
nano .env.production    # replace ChangeMe*
./scripts/deploy.sh production
```

Full VPS steps: [docs/DEPLOY-VPS.md](docs/DEPLOY-VPS.md).

## Rebuild from scratch

Deletes MySQL data only (keeps Redis / ES / uploads), rebuilds without cache, then starts:

```powershell
.\scripts\rebuild-fresh.ps1
.\scripts\rebuild-fresh.ps1 -Env production
```

```bash
./scripts/rebuild-fresh.sh
./scripts/rebuild-fresh.sh production
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

**Local (IP + ports):**

| URL | Expected |
|-----|----------|
| `http://127.0.0.1:4001/health` | Jobs API |
| `http://127.0.0.1:4002/api/health` | Marketplace API |

**Production (Nginx domains):**

| URL | Expected |
|-----|----------|
| `https://devminds.net/health` | `ok` (landing) |
| `https://jobs.devminds.net/health` | Proxied to jobs-backend `:4000/health` |
| `https://marketplace.devminds.net/health` | Proxied to marketplace-backend `:4000/api/health` |

```bash
docker compose ps
docker compose logs -f jobs-backend marketplace-backend nginx
```

## Services

| Service | Image / build | Notes |
|---------|---------------|-------|
| `mysql` | `mysql:8.4` | Init script creates DBs; healthcheck enabled |
| `redis` | `redis:7.4-alpine` | AOF + requirepass |
| `elasticsearch` | `8.15.3` | Single-node, security off, 512m heap |
| `jobs-backend` | Dockerfile | Migrate + optional seed/reindex |
| `jobs-worker` | Same image | `node ./src/queue/imageProcessor.js` |
| `jobs-frontend` | Next.js | Bakes `NEXT_PUBLIC_API_BASE` |
| `marketplace-backend` | Dockerfile | Admin/demo seeds via flags |
| `marketplace-frontend` | Next.js | Bakes marketplace public + internal `API_BASE` |
| `nginx` | `1.27-alpine` | HTTP + HTTPS + ACME webroot |

## Environment notes

- Templates: `.env.local` (IP:ports) and `.env.production` (domains). Active file is always `.env`.
- Local deploy uses `docker-compose.yml` + `docker-compose.local.yml`. Production uses `docker-compose.yml` only (Nginx).
- `MYSQL_USER` must stay `devminds`. Special characters in `DATABASE_URL_*` must be URL-encoded (`@` → `%40`).
- Keep `REDIS_PASSWORD` and `REDIS_URL` in sync.
- Frontend `NEXT_PUBLIC_*` values are **build args** — rebuild frontends after changing public URLs.
- Seed/reindex flags: `RUN_JOBS_SEEDS`, `RUN_MARKETPLACE_ADMIN_SEED`, `RUN_MARKETPLACE_DEMO_SEEDS`, `RUN_ES_REINDEX`.

## TLS

Development certs:

```powershell
openssl req -x509 -nodes -newkey rsa:2048 -days 825 `
  -keyout nginx/certs/privkey.pem `
  -out nginx/certs/fullchain.pem `
  -subj "/CN=devminds.net" `
  -addext "subjectAltName=DNS:devminds.net,DNS:www.devminds.net,DNS:jobs.devminds.net,DNS:marketplace.devminds.net,DNS:marketplace.devminds.com"
```

Replace with Let’s Encrypt for production; keep the same filenames. See [docs/DEPLOY-VPS.md](docs/DEPLOY-VPS.md).
