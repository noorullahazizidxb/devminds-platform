# syntax=docker/dockerfile:1
# Marketplace frontend - Next.js multi-stage image
FROM node:20-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-bookworm-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_API_BASE=https://marketplace.devminds.com/api
ARG NEXT_PUBLIC_API_BASE_URL=https://marketplace.devminds.com/api
ARG NEXT_PUBLIC_WS_URL=https://marketplace.devminds.com
ARG NEXT_PUBLIC_SOCKET_URL=https://marketplace.devminds.com
ARG NEXT_PUBLIC_SITE_URL=https://marketplace.devminds.com
ARG API_BASE=http://marketplace-backend:4000/api
ARG NEXT_PUBLIC_ENABLE_ELASTIC_SEARCH=true
ENV NEXT_PUBLIC_API_BASE=$NEXT_PUBLIC_API_BASE
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_WS_URL=$NEXT_PUBLIC_WS_URL
ENV NEXT_PUBLIC_SOCKET_URL=$NEXT_PUBLIC_SOCKET_URL
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV API_BASE=$API_BASE
ENV NEXT_PUBLIC_ENABLE_ELASTIC_SEARCH=$NEXT_PUBLIC_ENABLE_ELASTIC_SEARCH
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
RUN npm run build

FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
ENV API_BASE=http://marketplace-backend:4000/api

COPY --from=builder /app/package.json ./
COPY --from=builder /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./next.config.js
COPY --from=builder /app/next.config.mjs ./next.config.mjs
# Theme settings persist in .data/ui-context.json at runtime (created on first boot).
# theme-data/ was removed when HSL file themes were collapsed into ui-context.
# Locales live in src/lib/i18n.ts and ship inside the Next build - no i18n/ folder.
RUN mkdir -p .data

EXPOSE 3000
CMD ["npm", "run", "start"]
