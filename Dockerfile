# ---------- Build stage: compile the static site with Bun ----------
FROM oven/bun:1-debian AS build
WORKDIR /app

# rST series (content/series/rst-*) render through Python docutils.
# Without python3 the build silently falls back to the low-fidelity JS parser.
# Debian's deb.debian.org is unreachable from CN networks, so point apt at the
# USTC mirror first (works both locally and on Tencent Cloud).
RUN sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null; \
    sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list 2>/dev/null; \
    apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-docutils python3-pygments \
 && rm -rf /var/lib/apt/lists/*

# Install dependencies first for better layer caching.
COPY package.json bun.lock ./
COPY packages/create-amytis/package.json packages/create-amytis/package.json
RUN bun install --frozen-lockfile

# Copy sources and build the static export into out/.
# `bun run build` runs: copy-assets → knowledge graph → next build →
# image optimization (sharp) → locale html lang → link check → Pagefind index.
COPY . .
RUN bun run build

# ---------- Serve stage: nginx hosts out/ ----------
FROM nginx:alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/out /usr/share/nginx/html
EXPOSE 80
