# Run DevMinds Platform on localhost (IP + ports)

Orchestration lives in this repo. App sources are **sibling directories** next to `devminds-platform`.

**Local** = HTTP on `127.0.0.1` ports (no Nginx, no domains).  
**Production** = HTTPS domains via Nginx — see [DEPLOY-VPS.md](DEPLOY-VPS.md).

## Cheat sheet

```powershell
cd D:\projects\devminds-platform
.\scripts\deploy.ps1
```

| App | URL |
|-----|-----|
| Jobs UI | http://127.0.0.1:3001 |
| Marketplace UI | http://127.0.0.1:3002 |
| Jobs API health | http://127.0.0.1:4001/health |
| Marketplace API health | http://127.0.0.1:4002/api/health |

```powershell
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
docker compose -f docker-compose.yml -f docker-compose.local.yml down
```

---

## Step 1 — Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine + Compose v2
- Sibling repos:

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

---

## Step 2 — Environment (`.env.local`)

| File | Use |
|------|-----|
| `.env.local` | Localhost IP:port (default deploy) |
| `.env.production` | VPS domains + Nginx |
| `.env` | Active runtime copy (gitignored) |

```powershell
.\scripts\deploy.ps1              # copies .env.local → .env, uses docker-compose.local.yml
```

Default browser URLs in `.env.local`:

```env
LOCAL_PUBLIC_HOST=127.0.0.1
NEXT_PUBLIC_JOBS_API_BASE=http://127.0.0.1:4001
NEXT_PUBLIC_MARKETPLACE_API_BASE=http://127.0.0.1:4002/api
NEXT_PUBLIC_MARKETPLACE_WS_URL=http://127.0.0.1:4002
NEXT_PUBLIC_MARKETPLACE_SITE_URL=http://127.0.0.1:3002
```

For access from another device on your LAN, set those URLs to your machine IP (e.g. `http://180.222.140.40:3002`), then redeploy so frontends rebuild.

---

## Step 3 — Start

```powershell
cd D:\projects\devminds-platform
.\scripts\deploy.ps1
```

```bash
./scripts/deploy.sh
```

What starts locally:

- MySQL, Redis, Elasticsearch (internal Docker network only)
- Jobs API `:4001`, Marketplace API `:4002`
- Jobs UI `:3001`, Marketplace UI `:3002`
- **Nginx is not started** locally

On first boot: MySQL init → `prisma migrate deploy` → optional seeds.

---

## Step 4 — Verify

```powershell
curl http://127.0.0.1:4001/health
curl http://127.0.0.1:4002/api/health
curl -I http://127.0.0.1:3001
curl -I http://127.0.0.1:3002
```

```powershell
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f jobs-backend marketplace-backend
```

---

## Step 5 — Optional seeds / ES reindex

Edit `.env.local`, then:

```powershell
Copy-Item .env.local .env -Force
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --force-recreate jobs-backend marketplace-backend
```

---

## Day-2 ops

| Goal | Command |
|------|---------|
| Status | `docker compose -f docker-compose.yml -f docker-compose.local.yml ps` |
| Fresh MySQL + rebuild | `.\scripts\rebuild-fresh.ps1` |
| Clean volumes | `.\scripts\clean-docker.ps1 -Volumes` |
| Stop | `docker compose -f docker-compose.yml -f docker-compose.local.yml down` |

After changing any `NEXT_PUBLIC_*` value:

```powershell
.\scripts\deploy.ps1
```

(Frontends must rebuild because public URLs are build-time.)

---

## Troubleshooting

### Build EOF / disk

```powershell
docker builder prune -f
docker compose -f docker-compose.yml -f docker-compose.local.yml build jobs-backend
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

### Redis auth errors

Keep `REDIS_PASSWORD` and `REDIS_URL` in sync.

### LAN phone/tablet cannot connect

1. Set `LOCAL_PUBLIC_HOST` / all `NEXT_PUBLIC_*` to your LAN IP (not `127.0.0.1`).
2. Allow ports `3001`, `3002`, `4001`, `4002` in Windows Firewall.
3. Redeploy: `.\scripts\deploy.ps1`.

---

## Appendix — Backend start lifecycle

| Step | Marketplace | Jobs API | Jobs worker |
|------|-------------|----------|-------------|
| Wait for MySQL | Yes | Yes | No |
| `prisma migrate deploy` | Always | Always | Skipped |
| Seed | Admin / demo via flags | `prisma db seed` via flag | Skipped |
| ES reindex | If `RUN_ES_REINDEX` | If `RUN_ES_REINDEX` | Skipped |
