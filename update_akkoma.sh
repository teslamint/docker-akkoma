#!/usr/bin/env bash
set -x
#set -e
set -u
set -o pipefail

DOCKER_COMPOSE=$(which docker-compose)
if [[ "z$DOCKER_COMPOSE" = "z" ]]; then
  DOCKER_COMPOSE="docker compose"
fi

reload_nginx() {  
  $DOCKER_COMPOSE exec -T nginx /usr/sbin/nginx -s reload  
}

zero_downtime_deploy() {
  service_name=web
  old_container_id=$(docker ps -f name=$service_name -q | tail -n1)

  # bring a new container online, running new code  
  # (nginx continues routing to the old container only)  
  $DOCKER_COMPOSE up -d --no-deps --scale $service_name=2 --no-recreate $service_name

  # wait for new container to be available  
  new_container_id=$(docker ps -f name=$service_name -q | head -n1)
  new_container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $new_container_id)
  curl --silent --include --retry-connrefused --retry 30 --retry-delay 1 --fail http://$new_container_ip:4000/api/v1/pleroma/healthcheck || exit 1

  # start routing requests to the new container (as well as the old)  
  reload_nginx

  # take the old container offline  
  docker stop $old_container_id
  docker rm $old_container_id

  $DOCKER_COMPOSE up -d --no-deps --scale $service_name=1 --no-recreate $service_name

  # stop routing requests to the old container  
  reload_nginx  
}

BRANCH=develop

# check image already built
docker pull teslamint/akkoma:${BRANCH}

zero_downtime_deploy
# $DOCKER_COMPOSE up -d

# install frontends
if [ ! -d pleroma/static/frontends ]; then
    mkdir -p pleroma/static/frontends || chown 911:911 pleroma/static/frontends
fi
SERVICE_INDEX=$($DOCKER_COMPOSE ps web|tail -n1|awk '{print $1}'|sed -e s,pleroma-web-,,)
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install pleroma-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install admin-fe --ref ${BRANCH}
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install mastodon-fe --ref akkoma
$DOCKER_COMPOSE exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install fedibird-fe --ref akkoma

IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
