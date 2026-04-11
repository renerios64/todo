# ── Stage 1: Build ──────────────────────────────────────────────────────────
# Node is only needed to compile the React app into static files
FROM node:24-alpine AS build
WORKDIR /app

# Same cache trick — copy package files first, install deps, then copy source.
# npm install only re-runs when package.json or package-lock.json changes.
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build. Vite outputs to /app/dist
COPY . .
RUN npm run build

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# nginx is a tiny, battle-hardened static file server (~40MB vs ~200MB for node)
FROM nginx:alpine AS runtime

# Copy the compiled static files into nginx's default serving directory
COPY --from=build /app/dist /usr/share/nginx/html

# Copy our custom nginx config (handles SPA client-side routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
