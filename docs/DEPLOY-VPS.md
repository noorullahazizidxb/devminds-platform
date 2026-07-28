# Deploy DevMinds Platform on Ubuntu VPS

Target: Ubuntu 22.04/24.04, Docker Compose, production domains (`devminds.net`, `jobs.devminds.net`, `marketplace.devminds.net` / `.com`), Let’s Encrypt TLS into `nginx/certs/`.

## 1. Server requirements

- **RAM:** 4–8 GB minimum (Elasticsearch uses ~512m heap)
- **Disk:** ≥20 GB free for images + MySQL/ES volumes
- **Ports:** 22 (SSH), 80, 443 open
- **DNS:** A/AAAA for all domains pointing at the VPS **before** issuing certs

## 2. Install Docker + firewall

```bash
sudo apt update
sudo apt install -y ca-certificates curl git ufw

# Official Docker Engine + Compose plugin (Ubuntu):
# https://docs.docker.com/engine/install/ubuntu/
# After install, ensure: docker compose version

sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Add your deploy user to the `docker` group if needed: `sudo usermod -aG docker $USER` (re-login).

## 3. Clone layout (sibling contexts)

Compose build contexts are **relative** to `devminds-platform`. Use this layout:

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
# Clone each private/public repo into the paths above
git clone <devminds-platform-url> devminds-platform
# ... clone sibling apps into the matching folders
```

## 4. Configure `.env`

```bash
cd ~/projects/devminds-platform
cp .env.example .env
nano .env   # or vim
```

Replace every `ChangeMe*` value:

| Group | Action |
|-------|--------|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | Strong secrets; URL-encode special chars in `DATABASE_URL_*` |
| `REDIS_PASSWORD` / `REDIS_URL` | Keep consistent |
| `TOKEN_SECRET`, `JWT_SECRET`, `SESSION_SECRET`, `AUTH_COOKIE_SECRET` | Unique random strings |
| Domains | Production hostnames |
| `NEXT_PUBLIC_JOBS_API_BASE` | `https://jobs.devminds.net` |
| `NEXT_PUBLIC_MARKETPLACE_*` | Match `marketplace.devminds.net` or `.com` as served |
| Seeds | First boot: `RUN_MARKETPLACE_ADMIN_SEED=true`; set `false` after |
| `ADMIN_PASSWORD` | Change immediately after first login |

Do **not** commit `.env`.

## 5. First bring-up (self-signed smoke)

```bash
cd ~/projects/devminds-platform
chmod +x scripts/*.sh
./scripts/deploy.sh
docker compose ps
curl -k https://jobs.devminds.net/health
curl -k https://marketplace.devminds.net/health
curl -k https://devminds.net/health
```

Self-signed certs ship under `nginx/certs/`. Proceed once health checks pass.

## 6. Let’s Encrypt (production TLS)

Nginx expects:

- `/etc/nginx/certs/fullchain.pem` → host `nginx/certs/fullchain.pem`
- `/etc/nginx/certs/privkey.pem` → host `nginx/certs/privkey.pem`

Webroot stub: `nginx/www/certbot/`.

### Issue (example with certbot webroot)

```bash
sudo apt install -y certbot

# Ensure stack is up so port 80 hits nginx
cd ~/projects/devminds-platform
docker compose up -d nginx

# Certbot webroot — map challenge dir into the nginx container mount.
# Adjust -w to the host path that nginx serves as ACME root (nginx/www/certbot).
sudo certbot certonly --webroot \
  -w "$(pwd)/nginx/www/certbot" \
  -d devminds.net -d www.devminds.net \
  -d jobs.devminds.net \
  -d marketplace.devminds.net -d marketplace.devminds.com \
  --email admin@devminds.net --agree-tos --no-eff-email
```

If webroot challenges fail, use a temporary standalone stop of nginx on 80, or DNS-01. After issuance:

```bash
# Copy live certs into the filenames nginx already uses
sudo cp /etc/letsencrypt/live/devminds.net/fullchain.pem nginx/certs/fullchain.pem
sudo cp /etc/letsencrypt/live/devminds.net/privkey.pem nginx/certs/privkey.pem
sudo chown "$USER:$USER" nginx/certs/*.pem
docker compose exec nginx nginx -s reload
```

### Renew cron

```bash
sudo crontab -e
# Example daily renew + reload nginx
0 3 * * * certbot renew --quiet --deploy-hook "cp /etc/letsencrypt/live/devminds.net/fullchain.pem /home/USER/projects/devminds-platform/nginx/certs/fullchain.pem && cp /etc/letsencrypt/live/devminds.net/privkey.pem /home/USER/projects/devminds-platform/nginx/certs/privkey.pem && cd /home/USER/projects/devminds-platform && docker compose exec -T nginx nginx -s reload"
```

(Adjust paths/user to match the VPS.)

## 7. Hardening

- After first successful boot, keep seeds off for subsequent restarts:
  - `RUN_JOBS_SEEDS=false`
  - `RUN_MARKETPLACE_ADMIN_SEED=true` (idempotent admin ensure — safe) or `false` once admin exists
  - `RUN_MARKETPLACE_DEMO_SEEDS=false`
  - `RUN_ES_REINDEX=false`
- Optional: `fail2ban`, unattended-upgrades
- Backup MySQL regularly:

```bash
docker compose exec -T mysql \
  mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --databases marketplace job_portal \
  > backup-$(date +%F).sql
```

- Monitor disk: `docker system df`, volumes `mysql-data` / `elastic-data`

## 8. Updates / redeploy

```bash
cd ~/projects/devminds-platform
git pull
# Also pull sibling app repos
./scripts/deploy.sh
```

### Prisma on every backend start

| Step | Marketplace | Jobs API |
|------|-------------|----------|
| `prisma generate` | Image build (`postinstall` + explicit `npx prisma generate`) | Image build (`npx prisma generate`) |
| `prisma migrate deploy` | Entrypoint (always) | Entrypoint (always) |
| Seeds | `seedAdmin.js` if `RUN_MARKETPLACE_ADMIN_SEED=true`; `seedAll.js` if `RUN_MARKETPLACE_DEMO_SEEDS=true` | `prisma db seed` if `RUN_JOBS_SEEDS=true` |
| ES reindex | Optional if `RUN_ES_REINDEX=true` | Optional if `RUN_ES_REINDEX=true` |

Jobs worker reuses the jobs image but skips migrate/seed (custom entrypoint). Frontend images rebuild when sources or `NEXT_PUBLIC_*` change.
