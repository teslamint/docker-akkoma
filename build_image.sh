#!/usr/bin/env bash
set -x
set -euo pipefail

BRANCH=${BRANCH:-develop}
IMAGE=${IMAGE:-teslamint/akkoma}
COMMIT_HASH=$(curl "https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/branches/$BRANCH" | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-$BRANCH}
TAG=${TAG:-}
if [ "$BRANCH" = "stable" ]; then
    if [ -z "$TAG" ]; then
        LATEST_TAG_DATA=$(curl 'https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/tags/'|jq -r '.[0]')
        TAG=$(echo $LATEST_TAG_DATA|jq -r '.name')
        COMMIT_HASH=$(echo $LATEST_TAG_DATA| jq -r '.commit.sha')
    else
        COMMIT_HASH=$(curl "https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/tags/$TAG"| jq -r '.commit.sha')
        if [ -z "$COMMIT_HASH" ]; then
            echo "Tag $TAG not found"
            exit 1
        fi
    fi
fi

# check image already built
docker pull ${IMAGE}:${BRANCH} || true
docker pull ${IMAGE}:${COMMIT_ID} || true
if [ "$BRANCH" = "stable" ]; then
    docker pull ${IMAGE}:${TAG} || true
elif [ "$BRANCH" = "develop" ]; then
    docker pull ${IMAGE}:latest || true
fi

TAGS="-t ${IMAGE}:${BRANCH} -t ${IMAGE}:${COMMIT_ID}"
if [ "$BRANCH" = "develop" ]; then
    TAGS="-t ${IMAGE}:latest $TAGS"
elif [ "$BRANCH" = "stable" ]; then
    TAGS="-t ${IMAGE}:${TAG} $TAGS"
fi

docker buildx build --rm $TAGS . --progress plain \
    --build-arg "BRANCH=$BRANCH" --build-arg "PLEROMA_VER=$COMMIT_ID" --platform "linux/amd64,linux/arm64" --push
