#!/usr/bin/env bash
set -uo pipefail

DOCKER_COMPOSE=$(which docker-compose)
if [[ "z$DOCKER_COMPOSE" = "z" ]]; then
  DOCKER_COMPOSE="docker compose"
fi

reload_nginx() {  
  $DOCKER_COMPOSE exec -T nginx /usr/sbin/nginx -s reload  
}

BRANCH=develop

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
SERVICE_INDEX=$($DOCKER_COMPOSE ps web|tail -n1|awk '{print $1}'|sed -e s,akkoma-web-,,)
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install pleroma-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install admin-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install mastodon-fe --ref akkoma

IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
