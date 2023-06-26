#!/usr/bin/env bash
set -uo pipefail

BRANCH=${BRANCH:-develop}
DOCKER_COMPOSE=$(which docker-compose)
if [[ "z$DOCKER_COMPOSE" = "z" ]]; then
  DOCKER_COMPOSE="docker compose"
fi

get_service_index() {
  SERVICE_NAME=$1
  $DOCKER_COMPOSE ps $SERVICE_NAME|tail -n1|awk '{print $1}'|sed -e s,akkoma-$SERVICE_NAME-,,
}

reload_nginx() {
  NGINX_SERVICE_INDEX=$(get_service_index nginx)
  $DOCKER_COMPOSE exec -T --index=$NGINX_SERVICE_INDEX nginx /usr/sbin/nginx -s reload
}

# check image already built
$DOCKER_COMPOSE pull

# docker rollout plugin required: https://github.com/Wowu/docker-rollout
docker rollout web
# stop routing requests to the old container
reload_nginx

# install frontends
if [ ! -d pleroma/static/frontends ]; then
    mkdir -p pleroma/static/frontends
fi
SERVICE_INDEX=$(get_service_index web)
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install pleroma-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install admin-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install mastodon-fe --ref akkoma

IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
