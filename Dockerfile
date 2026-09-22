# Build stage
FROM node:22.1.0-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Runtime stage
FROM node:22.1.0-alpine
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/node_modules ./node_modules
COPY . .

ENV PORT=8080
EXPOSE 8080

USER appuser

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:${PORT}/live || exit 1

CMD ["node", "app.js"]
