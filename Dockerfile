# Build stage
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

# Runtime stage
FROM node:22-alpine
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/node_modules ./node_modules
COPY app.js ./
COPY package*.json ./

# Remove npm and its bundled dependencies - not needed at runtime,
# and their transitive deps (tar, minimatch, pacote, etc.) show up
# as vulnerabilities in image scans even though the app never uses them.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

ENV PORT=8080
EXPOSE 8080

USER appuser

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:${PORT}/live || exit 1

CMD ["node", "app.js"]
