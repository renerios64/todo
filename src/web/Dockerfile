# ── Stage 1: Build ──────────────────────────────────────────────────────────
# Node is only needed to compile the React app into static files
FROM --platform=linux/amd64 node:24-alpine AS build
WORKDIR /app

# Same cache trick — copy package files first, install deps, then copy source.
# npm install only re-runs when package.json or package-lock.json changes.
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build. Vite outputs to /app/dist
COPY . .
RUN npm run build

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM --platform=linux/amd64 nginx:alpine AS runtime

COPY --from=build /app/dist /usr/share/nginx/html

# Copy as a template — nginx alpine automatically runs envsubst on files in
# /etc/nginx/templates/ at startup, replacing ${API_URL} with the env var value.
COPY nginx.azure.conf /etc/nginx/templates/default.conf.template

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
