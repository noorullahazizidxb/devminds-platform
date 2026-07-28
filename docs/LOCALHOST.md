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
| Prisma seeds | `RUN_JOBS_SEEDS`, `RUN_MARKETPLACE_ADMIN_SEED`, `RUN_MARKETPLACE_DEMO_SEEDS`, `RUN_ES_REINDEX` |

## Prisma: generate, migrate, seeds (mandatory)

Backends own the database lifecycle. You do **not** run Prisma by hand for Compose boots — Dockerfiles and entrypoints do it.

MySQL first-boot (`mysql/init/01-create-databases.sql`) creates `marketplace` and `job_portal`. Then each API container:

1. waits for MySQL
2. runs `npx prisma migrate deploy`
3. optionally seeds
4. starts the Node process

| Project | Image build | Container start | Seed command | Compose env → container |
|---------|-------------|-----------------|--------------|-------------------------|
| **Marketplace** (`MarketPlace-Back-End-Node-Parisma`) | Copy `prisma/` before `npm ci` (postinstall `prisma generate`), then `npx prisma generate` again | `npx prisma migrate deploy` | Admin: `node scripts/seedAdmin.js` (default **on**). Demo: `node scripts/seedAll.js` (default **off**) | `RUN_MARKETPLACE_ADMIN_SEED` → `RUN_SEEDS`; `RUN_MARKETPLACE_DEMO_SEEDS` → `RUN_DEMO_SEEDS` |
| **Jobs API** (`job-service-back-end`) | `COPY prisma` then `npx prisma generate` | `npx prisma migrate deploy` | `npx prisma db seed` → `prisma/seed.js` (default **off**) | `RUN_JOBS_SEEDS` → `RUN_SEEDS` |
| **Jobs worker** | Same image (client generated at build) | **No** migrate/seed — entrypoint overridden to `imageProcessor.js` | — | — |

Recommended first localhost boot:

```env
RUN_JOBS_SEEDS=false
RUN_MARKETPLACE_ADMIN_SEED=true
RUN_MARKETPLACE_DEMO_SEEDS=false
RUN_ES_REINDEX=false
ADMIN_EMAIL=...
ADMIN_PASSWORD=...
```

Turn on jobs demo data or marketplace demo / ES reindex only when you explicitly want a full sample dataset:

```env
RUN_JOBS_SEEDS=true
RUN_MARKETPLACE_DEMO_SEEDS=true
RUN_ES_REINDEX=true
```

Then recreate the backend containers so entrypoints re-run:

```powershell
docker compose up -d --force-recreate jobs-backend marketplace-backend
```

Local (non-Docker) one-offs from each backend repo:

```bash
# Marketplace
npm run generate && npx prisma migrate deploy && npm run seed:admin   # optional: npm run seed:all

# Jobs
npm run generate && npx prisma migrate deploy && npm run seed
```

Do **not** use `prisma migrate dev` inside production/Compose images — entrypoints use `migrate deploy` only.

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

