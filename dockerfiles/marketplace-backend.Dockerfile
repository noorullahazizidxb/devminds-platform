# syntax=docker/dockerfile:1
# Marketplace API - Node 20
FROM node:20-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY . .

ENV NODE_ENV=production
ENV PORT=4000
ENV RUN_SEEDS=true

COPY <<'ENTRY' /app/docker-entrypoint.sh
#!/bin/sh
set -e

echo "[marketplace-backend] Waiting for MySQL..."
i=0
until node --input-type=module -e '
import { PrismaClient } from "@prisma/client";
const p = new PrismaClient();
try {
  await p.$queryRaw`SELECT 1`;
  console.log("[marketplace-backend] MySQL ready");
  await p.$disconnect();
  process.exit(0);
} catch (e) {
  console.error(e.message || e);
  await p.$disconnect().catch(() => {});
  process.exit(1);
}
'; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "[marketplace-backend] MySQL wait timed out"
    exit 1
  fi
  sleep 2
done

echo "[marketplace-backend] Running prisma migrate deploy..."
npx prisma migrate deploy

if [ "${RUN_SEEDS:-true}" = "true" ]; then
  echo "[marketplace-backend] Seeding admin..."
  node scripts/seedAdmin.js || true
  echo "[marketplace-backend] Seeding all..."
  node scripts/seedAll.js || true
fi

if [ "${ENABLE_ELASTIC_SEARCH}" = "true" ]; then
  echo "[marketplace-backend] Initializing Elasticsearch indexes..."
  node scripts/initUsersIndex.js || true
  if [ "${RUN_ES_REINDEX}" = "true" ]; then
    node scripts/reindex-search.js || true
    node scripts/reindex-blogs.js || true
  fi
fi

echo "[marketplace-backend] Starting API..."
exec node ./src/index.js
ENTRY

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 4000
ENTRYPOINT ["/app/docker-entrypoint.sh"]