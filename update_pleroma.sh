#!/usr/bin/env bash
set -x
COMMIT_HASH=$(curl 'https://git.pleroma.social/api/v4/projects/2/repository/branches/stable' | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-stable}

docker buildx build --rm -t teslamint/pleroma:stable -t teslamint/pleroma:${COMMIT_ID} . --build-arg "PLEROMA_VER=$COMMIT_ID"
# docker-compose run --rm web mix ecto.migrate
docker-compose up -d
IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
docker push teslamint/pleroma:latest
docker push teslamint/pleroma:stable
docker push teslamint/pleroma:${COMMIT_ID}
