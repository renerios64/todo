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
FROM nginx:alpine AS runtime

COPY --from=build /app/dist /usr/share/nginx/html

# Hardcoded nginx config for Azure — no runtime substitution needed.
# The API's internal FQDN is stable as long as the Container Apps environment exists.
COPY nginx.azure.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
