#!/usr/bin/env bash
set -x
set -euo pipefail

AKKOMA_API="https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma"
BRANCH=${BRANCH:-develop}
IMAGE=${IMAGE:-teslamint/akkoma}
COMMIT_HASH=$(curl -sfS "${AKKOMA_API}/branches/$BRANCH" | jq -r '.commit.id // empty')
COMMIT_ID=${COMMIT_HASH:-$BRANCH}
TAG=${TAG:-}
if [ "$BRANCH" = "stable" ]; then
    if [ -z "$TAG" ]; then
        LATEST_TAG_DATA=$(curl -sfS "${AKKOMA_API}/tags/" | jq -r '.[0]')
        TAG=$(echo "$LATEST_TAG_DATA" | jq -r '.name // empty')
        COMMIT_HASH=$(echo "$LATEST_TAG_DATA" | jq -r '.commit.sha // empty')
    else
        COMMIT_HASH=$(curl -sfS "${AKKOMA_API}/tags/$TAG" | jq -r '.commit.sha // empty')
        if [ -z "$COMMIT_HASH" ]; then
            echo "Tag $TAG not found"
            exit 1
        fi
    fi
fi

# check image already built
docker pull "${IMAGE}:${BRANCH}" || echo "WARN: could not pull ${IMAGE}:${BRANCH}"
docker pull "${IMAGE}:${COMMIT_ID}" || echo "WARN: could not pull ${IMAGE}:${COMMIT_ID}"
if [ "$BRANCH" = "stable" ]; then
    docker pull "${IMAGE}:${TAG}" || echo "WARN: could not pull ${IMAGE}:${TAG}"
elif [ "$BRANCH" = "develop" ]; then
    docker pull "${IMAGE}:latest" || echo "WARN: could not pull ${IMAGE}:latest"
fi

TAGS="-t ${IMAGE}:${BRANCH} -t ${IMAGE}:${COMMIT_ID}"
if [ "$BRANCH" = "develop" ]; then
    TAGS="-t ${IMAGE}:latest $TAGS"
elif [ "$BRANCH" = "stable" ]; then
    TAGS="-t ${IMAGE}:${TAG} $TAGS"
fi

docker buildx build --rm $TAGS . --progress plain \
    --build-arg "BRANCH=$BRANCH" --build-arg "PLEROMA_VER=$COMMIT_ID" --platform "linux/amd64,linux/arm64" --push
