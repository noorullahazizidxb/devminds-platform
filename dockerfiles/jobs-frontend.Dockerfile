# Jobs frontend - Next.js multi-stage
# NEXT_PUBLIC_API_BASE must be origin only (no /api); client paths already start with /api
FROM node:20-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-bookworm-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_API_BASE=https://jobs.devminds.net
ARG NEXT_PUBLIC_API_HOST=https://jobs.devminds.net
ARG ELASTICSEARCH_NODE=http://elasticsearch:9200
ARG AUTH_COOKIE_SECRET=devminds_cookie_secret_change_me

ENV NEXT_PUBLIC_API_BASE=$NEXT_PUBLIC_API_BASE
ENV NEXT_PUBLIC_API_HOST=$NEXT_PUBLIC_API_HOST
ENV ELASTICSEARCH_NODE=$ELASTICSEARCH_NODE
ENV AUTH_COOKIE_SECRET=$AUTH_COOKIE_SECRET
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN npm run build

FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

COPY --from=builder /app/package.json ./
COPY --from=builder /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./next.config.ts

EXPOSE 3000
CMD ["npm", "run", "start"]
