#!/usr/bin/env bash
set -x
#set -e
set -u
set -o pipefail

reload_nginx() {  
  docker-compose exec -T nginx /usr/sbin/nginx -s reload  
}

zero_downtime_deploy() {
  service_name=web
  old_container_id=$(docker ps -f name=$service_name -q | tail -n1)

  # bring a new container online, running new code  
  # (nginx continues routing to the old container only)  
  docker-compose up -d --no-deps --scale $service_name=2 --no-recreate $service_name

  # wait for new container to be available  
  new_container_id=$(docker ps -f name=$service_name -q | head -n1)
  new_container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $new_container_id)
  while : ; do
    curl --silent --include --retry 30 --retry-delay 1 --fail http://$new_container_ip:4000/
    [[ $? -eq 7 ]] || break
  done

  # start routing requests to the new container (as well as the old)  
  reload_nginx

  # take the old container offline  
  docker stop $old_container_id
  docker rm $old_container_id

  docker-compose up -d --no-deps --scale $service_name=1 --no-recreate $service_name

  # stop routing requests to the old container  
  reload_nginx  
}

COMMIT_HASH=$(curl 'https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/branches/develop' | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-develop}

# check image already built
docker pull teslamint/akkoma:${COMMIT_ID} || true

docker buildx build --rm -t teslamint/akkoma:latest -t teslamint/akkoma:stable -t teslamint/akkoma:${COMMIT_ID} . --build-arg "PLEROMA_VER=$COMMIT_ID"
zero_downtime_deploy
docker-compose up -d

# install frontends
if [ ! -d static/frontends ]; then
    mkdir -p static/frontends || chown 911:911 static/frontends
fi
SERVICE_INDEX=$(docker-compose ps web|tail -n1|awk '{print $1}'|sed -e 's/pleroma_web_//')
docker-compose exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install pleroma-fe --ref develop
docker-compose exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install admin-fe --ref develop
docker-compose exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install mastodon-fe --ref akkoma
docker-compose exec -T --index=$SERVICE_INDEX web /pleroma/bin/pleroma_ctl frontend install fedibird-fe --ref akkoma

IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
docker push teslamint/akkoma:latest
docker push teslamint/akkoma:stable
docker push teslamint/akkoma:${COMMIT_ID}
