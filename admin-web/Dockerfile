FROM node:24-alpine AS build

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Next bakes rewrites into the build, so the API URL must be known at build time
ARG API_URL=http://api-gateway:8080
ENV API_URL=$API_URL

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:24-alpine

WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1

ARG API_URL=http://api-gateway:8080
ENV API_URL=$API_URL

COPY --from=build /app/package*.json /app/next.config.mjs ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next

USER node
EXPOSE 3000

CMD ["npm", "start"]
