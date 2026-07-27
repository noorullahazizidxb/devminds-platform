# syntax=docker/dockerfile:1
# Jobs API - Node.js, Prisma, MySQL, Redis, Socket.IO and Elasticsearch
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

COPY <<'ENTRY' /app/docker-entrypoint.sh
#!/bin/sh
set -eu

echo "[jobs-backend] Waiting for MySQL..."
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
    echo "[jobs-backend] MySQL wait timed out" >&2
    exit 1
  fi
  sleep 2
done

echo "[jobs-backend] Applying Prisma migrations..."
npx prisma migrate deploy

if [ "${RUN_SEEDS:-false}" = "true" ]; then
  echo "[jobs-backend] Seeding database..."
  npx prisma db seed
fi

if [ "${ENABLE_ELASTIC_SEARCH:-true}" = "true" ] && [ "${RUN_ES_REINDEX:-false}" = "true" ]; then
  echo "[jobs-backend] Reindexing Elasticsearch..."
  node -r dotenv/config ./scripts/reindex-all.js
fi

echo "[jobs-backend] Starting API..."
exec node ./src/index.js
ENTRY

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 4000
ENTRYPOINT ["/app/docker-entrypoint.sh"]