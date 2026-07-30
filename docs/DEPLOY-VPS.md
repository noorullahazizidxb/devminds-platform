# Deploy DevMinds Platform on Ubuntu VPS

Target: Ubuntu 22.04/24.04, Docker Compose, production domains (`devminds.net`, `jobs.devminds.net`, `marketplace.devminds.net` / `.com`), Let’s Encrypt TLS into `nginx/certs/`.

Local development uses IP:ports instead — see [LOCALHOST.md](LOCALHOST.md). Production deploy uses `.env.production` and **only** `docker-compose.yml` (DevMinds Nginx on localhost `8080`/`8443`; app ports stay internal).

If this VPS also runs NewLinkAF (`/opt/newlinkaf.com` → `ticket.newlinkaf.com`), start the **external edge gateway** so public 80/443 are shared — see [GATEWAY.md](GATEWAY.md).

## Cheat sheet

```bash
cd ~/projects/devminds-platform
nano .env.production          # replace every ChangeMe*
chmod +x scripts/*.sh
./scripts/deploy.sh production
docker compose ps
# If NewLinkAF shares this VPS, start the edge gateway (owns public 80/443):
cd gateway && docker compose up -d && cd ..
curl -k https://jobs.devminds.net/health
# then issue Let’s Encrypt (Step 6) and turn seed flags down (Step 7)
```

---

## Step 1 — Server requirements

- **RAM:** 4–8 GB minimum (Elasticsearch uses ~512m heap)
- **Disk:** ≥20 GB free for images + MySQL/ES volumes
- **Ports:** 22 (SSH), 80, 443 open (public 80/443 via `gateway/` when sharing the VPS with NewLinkAF)
- **DNS:** A/AAAA for all domains pointing at the VPS **before** issuing certs

---

## Step 2 — Install Docker + firewall

```bash
sudo apt update
sudo apt install -y ca-certificates curl git ufw

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "$USER"
# log out and back in, then:
docker compose version

sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## Step 3 — Clone sibling layout

Compose build contexts are **relative** to `devminds-platform`:

```text
~/projects/
  devminds-platform/
  Jobs_Complete_Back-End-and-Front-End/
    job-front-end/
    job-service-back-end/
  MarketPlace_Back_end__Front_End/
    marketplace-Front-end/
    MarketPlace-Back-End-Node-Parisma/
```

```bash
mkdir -p ~/projects
cd ~/projects
git clone <devminds-platform-url> devminds-platform
# Clone each sibling app into the matching folders above
```

---

## Step 4 — Configure `.env.production`

```bash
cd ~/projects/devminds-platform
nano .env.production
```

Replace every `ChangeMe*` value:

| Group | Action |
|-------|--------|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | Strong secrets; URL-encode special chars in `DATABASE_URL_*` (`@` → `%40`) |
| `MYSQL_USER` | Keep `devminds` (init SQL is hardcoded) |
| `REDIS_PASSWORD` / `REDIS_URL` | Keep consistent |
| `TOKEN_SECRET`, `JWT_SECRET`, `SESSION_SECRET`, `AUTH_COOKIE_SECRET` | Unique random strings |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | First admin; change after login |
| Seeds | First boot: `RUN_MARKETPLACE_ADMIN_SEED=true`; jobs/demo/reindex `false` |
| `NEXT_PUBLIC_*` | Production HTTPS URLs (rebuild frontends if you change them later) |

Notes:

- Domain vars are documentation only — Nginx hostnames are fixed in `nginx/conf.d/`.
- Leave `ELASTICSEARCH_USERNAME` empty (security off).
- Active runtime file is `.env` (gitignored). Deploy copies `.env.production` → `.env`.

Do **not** commit real production secrets.

---

## Step 5 — First bring-up (self-signed smoke)

```bash
cd ~/projects/devminds-platform
chmod +x scripts/*.sh
./scripts/deploy.sh production
docker compose ps

# Shared VPS with NewLinkAF: gateway must be up before public HTTPS works.
# NewLinkAF Nginx must bind 127.0.0.1:9080/9443 first — see GATEWAY.md.
cd gateway && docker compose up -d && cd ..

curl -k https://devminds.net/health
curl -k https://jobs.devminds.net/health
curl -k https://marketplace.devminds.net/health
```

Self-signed certs ship under `nginx/certs/`. Proceed once health checks pass.

Without the gateway (DevMinds-only VPS), you can temporarily publish DevMinds Nginx on 80/443 instead of localhost ports — prefer the gateway layout if NewLinkAF coexists.

On start, backends automatically:

1. Wait for MySQL
2. Run `prisma migrate deploy`
3. Run marketplace admin seed when `RUN_MARKETPLACE_ADMIN_SEED=true`
4. Start the Node processes (jobs worker skips migrate/seed)

---

## Step 6 — Let’s Encrypt (production TLS)

Nginx expects:

- Host `nginx/certs/fullchain.pem` → container `/etc/nginx/certs/fullchain.pem`
- Host `nginx/certs/privkey.pem` → container `/etc/nginx/certs/privkey.pem`

HTTP servers serve ACME challenges from `nginx/www/certbot` (mounted at `/var/www/certbot`).

### Issue (webroot)

```bash
sudo apt install -y certbot

cd ~/projects/devminds-platform
docker compose up -d nginx
# Keep the edge gateway up so public :80 reaches DevMinds Nginx (ACME webroot).
cd gateway && docker compose up -d && cd ..

sudo certbot certonly --webroot \
  -w "$(pwd)/nginx/www/certbot" \
  -d devminds.net -d www.devminds.net \
  -d jobs.devminds.net \
  -d marketplace.devminds.net \
  --email admin@devminds.net --agree-tos --no-eff-email
```

### Fallback (standalone)

If webroot fails, free port 80 briefly (stop the **gateway**, not only app Nginx):

```bash
cd ~/projects/devminds-platform/gateway && docker compose stop gateway-nginx
sudo certbot certonly --standalone \
  -d devminds.net -d www.devminds.net \
  -d jobs.devminds.net \
  -d marketplace.devminds.net \
  --email admin@devminds.net --agree-tos --no-eff-email
cd ~/projects/devminds-platform/gateway && docker compose start gateway-nginx
```

### Install certs into Nginx filenames

```bash
cd ~/projects/devminds-platform
sudo cp /etc/letsencrypt/live/devminds.net/fullchain.pem nginx/certs/fullchain.pem
sudo cp /etc/letsencrypt/live/devminds.net/privkey.pem nginx/certs/privkey.pem
sudo chown "$USER:$USER" nginx/certs/*.pem
docker compose exec nginx nginx -s reload
```

### Renew cron

```bash
sudo crontab -e
```

Replace `YOUR_USER` with your Linux username:

```cron
0 3 * * * certbot renew --quiet --deploy-hook "cp /etc/letsencrypt/live/devminds.net/fullchain.pem /home/YOUR_USER/projects/devminds-platform/nginx/certs/fullchain.pem && cp /etc/letsencrypt/live/devminds.net/privkey.pem /home/YOUR_USER/projects/devminds-platform/nginx/certs/privkey.pem && cd /home/YOUR_USER/projects/devminds-platform && docker compose exec -T nginx nginx -s reload"
```

---

## Step 7 — After first boot (hardening)

Edit `.env.production` (and re-copy), then recreate backends once:

```env
RUN_JOBS_SEEDS=false
RUN_MARKETPLACE_ADMIN_SEED=false
RUN_MARKETPLACE_DEMO_SEEDS=false
RUN_ES_REINDEX=false
```

```bash
cp .env.production .env
docker compose up -d --force-recreate jobs-backend marketplace-backend
```

Optional: `fail2ban`, unattended-upgrades.

Backup MySQL:

```bash
cd ~/projects/devminds-platform
set -a && source .env && set +a
docker compose exec -T mysql \
  mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --databases marketplace job_portal \
  > backup-$(date +%F).sql
```

Monitor disk: `docker system df`.

---

## Step 8 — Updates / redeploy

```bash
cd ~/projects/devminds-platform
git pull
# Also pull sibling app repos
./scripts/deploy.sh production
```

Fresh MySQL only (keeps Redis/ES/uploads):

```bash
./scripts/rebuild-fresh.sh production
```

After a MySQL reset, set `RUN_ES_REINDEX=true` once if search indices are stale, recreate backends, then set it back to `false`.

---

## Appendix — Prisma / seeds on every backend start

| Step | Marketplace | Jobs API | Jobs worker |
|------|-------------|----------|-------------|
| `prisma generate` | Image build | Image build | Image build |
| `prisma migrate deploy` | Entrypoint (always) | Entrypoint (always) | Skipped |
| Seeds | `seedAdmin.js` / `seedAll.js` via flags | `prisma db seed` via `RUN_JOBS_SEEDS` | Skipped |
| ES reindex | If `RUN_ES_REINDEX` | If `RUN_ES_REINDEX` | Skipped |

Frontend images rebuild when sources or `NEXT_PUBLIC_*` change.
