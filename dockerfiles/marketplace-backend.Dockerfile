# syntax=docker/dockerfile:1
# Marketplace API - Node.js, Prisma, MySQL, Redis, Socket.IO and Elasticsearch
FROM node:20-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# package.json runs `prisma generate` in postinstall, so the schema must exist
# before npm ci. This order is required for a clean Docker build.
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

COPY . .
RUN npx prisma generate

ENV NODE_ENV=production
ENV PORT=4000

COPY <<'ENTRY' /app/docker-entrypoint.sh
#!/bin/sh
set -eu

echo "[marketplace-backend] Waiting for MySQL..."
i=0
until node --input-type=module -e '
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();
try {
  await prisma.$queryRaw`SELECT 1`;
  await prisma.$disconnect();
  process.exit(0);
} catch (error) {
  console.error(error.message || error);
  await prisma.$disconnect().catch(() => {});
  process.exit(1);
}
'; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "[marketplace-backend] MySQL wait timed out" >&2
    exit 1
  fi
  sleep 2
done

echo "[marketplace-backend] Applying Prisma migrations..."
npx prisma migrate deploy

if [ "${RUN_SEEDS:-true}" = "true" ]; then
  echo "[marketplace-backend] Ensuring the admin account exists..."
  node scripts/seedAdmin.js
fi

if [ "${RUN_DEMO_SEEDS:-false}" = "true" ]; then
  echo "[marketplace-backend] Loading demo data..."
  node scripts/seedAll.js
fi

if [ "${ENABLE_ELASTIC_SEARCH:-true}" = "true" ] && [ "${RUN_ES_REINDEX:-false}" = "true" ]; then
  echo "[marketplace-backend] Reindexing Elasticsearch..."
  node scripts/reindex-search.js
  node scripts/reindex-blogs.js
fi

echo "[marketplace-backend] Starting API..."
exec node ./src/index.js
ENTRY

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 4000
ENTRYPOINT ["/app/docker-entrypoint.sh"]