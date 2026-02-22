# docker-pleroma (docker-akkoma)

Docker build/deployment wrapper for [Akkoma](https://akkoma.social/) — this repo contains no Akkoma source code; it builds from upstream and wraps it in a production-ready container stack.

## Architecture

```
Cloudflared → Caddy → Akkoma → PostgreSQL
                             → Meilisearch
                             → PgHero
```

All services are defined in `docker-compose.yml`. The external network `pleroma_v6` must be pre-created.

## Build

```bash
# Local build (requires BRANCH env var)
BRANCH=develop ./build_image.sh

# Direct Docker build
docker buildx build --build-arg BRANCH=develop .
```

CI (CircleCI) builds `stable` and `develop` branches automatically and pushes to `teslamint/akkoma`.

## Operations

```bash
# Start all services
docker compose up -d

# Rolling update Akkoma (requires docker-rollout plugin)
./update_akkoma.sh

# Database backup
./backup_database.sh
```

DB migrations run automatically at container startup via `docker-entrypoint.sh`.

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | 2-stage build: `emqx-builder` (compile) → `alpine` (runtime) |
| `config.exs` | Akkoma Elixir config, entirely env-var driven |
| `docker-entrypoint.sh` | Waits for DB, runs migrations, starts Akkoma |
| `patches/` | Quilt patch directory; `patches/series` defines apply order |
| `build_image.sh` | Wraps `docker buildx build` with tagging logic |
| `update_akkoma.sh` | Zero-downtime update using docker-rollout |
| `backup_database.sh` | pg_dump backup script |

## Patch System

Patches are applied at build time using [quilt](https://savannah.nongnu.org/projects/quilt). The `patches/series` file controls which patches are applied and in what order.

To skip patches entirely, comment out the `COPY patches` and `RUN quilt push -a` lines in the `Dockerfile`.

Current patches:
- Cloudflare R2 ACL removal (removes unsupported ACL header from R2 uploads)

## Environment

Six `.env.*.sample` files are provided. Copy each to its non-sample name and fill in values:

```bash
for f in .env.*.sample; do cp "$f" "${f%.sample}"; done
```

## Network

The external Docker network must be created before starting services:

```bash
docker network create pleroma_v6
```
