FROM node:24-alpine AS build

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Next bakes rewrites into the build, so the API URL must be known at build time
ARG API_URL=http://api-gateway:8080
ENV API_URL=$API_URL

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# output: 'standalone' — server.js plus only the node_modules it traces
# (https://nextjs.org/docs/app/api-reference/config/next-config-js/output)
FROM node:24-alpine

WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0

ARG API_URL=http://api-gateway:8080
ENV API_URL=$API_URL

COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static

USER node
EXPOSE 3000

CMD ["node", "server.js"]
