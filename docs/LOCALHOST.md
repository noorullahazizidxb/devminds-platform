# Run DevMinds Platform on localhost

Orchestration lives in this repo. App sources are **sibling directories** next to `devminds-platform`.

## Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine + Compose v2
- Sibling repos present:

```text
projects/
  devminds-platform/          ← you are here
  Jobs_Complete_Back-End-and-Front-End/
    job-front-end/
    job-service-back-end/
  MarketPlace_Back_end__Front_End/
    marketplace-Front-end/
    MarketPlace-Back-End-Node-Parisma/
```

Validated relative compose contexts (from `docker-compose.yml`):

- `../Jobs_Complete_Back-End-and-Front-End/job-service-back-end`
- `../Jobs_Complete_Back-End-and-Front-End/job-front-end`
- `../MarketPlace_Back_end__Front_End/MarketPlace-Back-End-Node-Parisma`
- `../MarketPlace_Back_end__Front_End/marketplace-Front-end`

## Environment

```bash
cd devminds-platform
cp .env.example .env   # skip if .env already exists
```

Key local values (defaults in `.env.example`):

| Area | Vars |
|------|------|
| Domains | `LANDING_DOMAIN`, `JOBS_DOMAIN`, `MARKETPLACE_DOMAIN`, `MARKETPLACE_ALIAS_DOMAIN` |
| MySQL | `MYSQL_*`, `DATABASE_URL_JOBS`, `DATABASE_URL_MARKETPLACE` |
| Redis | `REDIS_PASSWORD`, `REDIS_URL` |
| Public FE URLs | `NEXT_PUBLIC_JOBS_API_BASE`, `NEXT_PUBLIC_MARKETPLACE_*` (build-time) |

## Hosts file

Add to `C:\Windows\System32\drivers\etc\hosts` (Windows) or `/etc/hosts` (macOS/Linux):

```text
127.0.0.1  devminds.net www.devminds.net jobs.devminds.net marketplace.devminds.net marketplace.devminds.com
```

## Start

```powershell
cd D:\projects\devminds-platform
docker compose config --quiet    # validate
docker compose up -d --build
# or: .\scripts\deploy.ps1
```

```bash
cd ~/projects/devminds-platform
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Only **80** and **443** are published (Nginx). Backend/frontend ports stay on the Docker network.

## Verify

| URL | Expected |
|-----|----------|
| https://devminds.net/health | `ok` |
| https://jobs.devminds.net/health | jobs-backend health |
| https://marketplace.devminds.net/health | marketplace-backend health |

Self-signed certs in `nginx/certs/` — browsers will warn; continue for local smoke tests.

```bash
docker compose ps
docker compose logs -f nginx jobs-backend marketplace-backend
```

## Ops

| Goal | Command |
|------|---------|
| Status | `docker compose ps` |
| Fresh MySQL + rebuild | `.\scripts\rebuild-fresh.ps1` / `./scripts/rebuild-fresh.sh` |
| Clean | `.\scripts\clean-docker.ps1 -Volumes` / `./scripts/clean-docker.sh --volumes` |
| Stop | `docker compose down` |

**Rebuild frontends** after changing any `NEXT_PUBLIC_*` value — those are baked at image build time.

## Troubleshooting: `rpc error ... EOF` during build

This usually means Docker Desktop ran out of **disk** or **memory** while building several services in parallel (`npm ci` × 4).

1. Free space (host drive + Docker):

```powershell
docker builder prune -f
docker image prune -a -f   # optional: remove unused images
docker system df
```

2. Rebuild **one service at a time**, then bring the stack up:

```powershell
docker compose build marketplace-backend
docker compose build jobs-backend jobs-worker
docker compose build marketplace-frontend jobs-frontend
docker compose up -d
```

3. In Docker Desktop → Settings → Resources, give the VM enough disk (≥40 GB recommended) and memory (≥8 GB).

4. Retry full build only after free disk is comfortable:

```powershell
docker compose up -d --build
```

