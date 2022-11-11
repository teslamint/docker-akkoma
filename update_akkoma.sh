#!/usr/bin/env bash
set -x
COMMIT_HASH=$(curl 'https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/branches/stable' | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-stable}

docker buildx build --rm -t teslamint/akkoma:latest -t teslamint/akkoma:stable -t teslamint/akkoma:${COMMIT_ID} . --build-arg "PLEROMA_VER=$COMMIT_ID"
# docker-compose run --rm web mix ecto.migrate
docker-compose up -d
IMAGES=$(docker images -f "dangling=true" -q)
if [ "$IMAGES" != "" ]; then
    docker rmi --force $IMAGES
fi
docker system prune -f
docker push teslamint/akkoma:latest
docker push teslamint/akkoma:stable
docker push teslamint/akkoma:${COMMIT_ID}
