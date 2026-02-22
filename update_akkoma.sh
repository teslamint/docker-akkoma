#!/usr/bin/env bash
set -euo pipefail

BRANCH=${BRANCH:-develop}
MASTOFE_REF=${MASTOFE_REF:-akkoma}
FEDIBIRD_REF=${FEDIBIRD_REF:-akkoma}

if command -v docker-compose > /dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
else
  DOCKER_COMPOSE="docker compose"
fi

get_service_index() {
  SERVICE_NAME=$1
  $DOCKER_COMPOSE ps --format json "$SERVICE_NAME" | jq -r '.[0].Name' | sed -e "s,akkoma-${SERVICE_NAME}-,,"
}

# check image already built
$DOCKER_COMPOSE pull

# docker rollout plugin required: https://github.com/Wowu/docker-rollout
docker rollout web --pre-stop-hook "touch /tmp/drain && sleep 10"

# reload caddy
$DOCKER_COMPOSE exec -w /etc/caddy caddy caddy reload

# install frontends
if [ ! -d pleroma/static/frontends ]; then
    mkdir -p pleroma/static/frontends
fi
SERVICE_INDEX=$(get_service_index web)
$DOCKER_COMPOSE exec -T --index="$SERVICE_INDEX" web /pleroma/bin/pleroma_ctl frontend install pleroma-fe --ref "${BRANCH}"
$DOCKER_COMPOSE exec -T --index="$SERVICE_INDEX" web /pleroma/bin/pleroma_ctl frontend install admin-fe --ref "${BRANCH}"
$DOCKER_COMPOSE exec -T --index="$SERVICE_INDEX" web /pleroma/bin/pleroma_ctl frontend install mastodon-fe --ref "${MASTOFE_REF}"
$DOCKER_COMPOSE exec -T --index="$SERVICE_INDEX" web /pleroma/bin/pleroma_ctl frontend install fedibird-fe --ref "${FEDIBIRD_REF}"

docker images -f "dangling=true" -q | xargs -r docker rmi --force || true
docker system prune -f
