# syntax=docker/dockerfile:1
# Jobs API - Node 20
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

# Entrypoint: wait for MySQL (Prisma SELECT 1), migrate, optional seed/reindex, start API
COPY <<'ENTRY' /app/docker-entrypoint.sh
#!/bin/sh
set -e

echo "[jobs-backend] Waiting for MySQL..."
i=0
until node --input-type=module -e '
import { PrismaClient } from "@prisma/client";
const p = new PrismaClient();
try {
  await p.$queryRaw`SELECT 1`;
  console.log("[jobs-backend] MySQL ready");
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
    echo "[jobs-backend] MySQL wait timed out"
    exit 1
  fi
  sleep 2
done

echo "[jobs-backend] Running prisma migrate deploy..."
npx prisma migrate deploy

if [ "${RUN_SEEDS}" = "true" ]; then
  echo "[jobs-backend] Seeding database..."
  npx prisma db seed || node prisma/seed.js || true
fi

if [ "${ENABLE_ELASTIC_SEARCH}" = "true" ] && [ "${RUN_ES_REINDEX}" = "true" ]; then
  echo "[jobs-backend] Reindexing Elasticsearch..."
  node -r dotenv/config ./scripts/reindex-all.js || true
fi

echo "[jobs-backend] Starting API..."
exec node ./src/index.js
ENTRY

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 4000
ENTRYPOINT ["/app/docker-entrypoint.sh"]