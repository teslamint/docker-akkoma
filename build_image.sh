#!/usr/bin/env bash
set -x
set -e
set -u
set -o pipefail

BRANCH=${BRANCH:-develop}
IMAGE=${IMAGE:-teslamint/akkoma}
COMMIT_HASH=$(curl "https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/branches/$BRANCH" | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-$BRANCH}

# check image already built
docker pull ${IMAGE}:${BRANCH} || true
docker pull ${IMAGE}:${COMMIT_ID} || true

TAGS="-t ${IMAGE}:${BRANCH} -t ${IMAGE}:${COMMIT_ID}"
if [[ "$BRANCH" = "develop" ]]; then
    TAGS="-t ${IMAGE}:latest $TAGS"
fi

docker buildx build --rm $TAGS . \
    --build-arg "BRANCH=$BRANCH" --build-arg "PLEROMA_VER=$COMMIT_ID" --platform "linux/amd64,linux/arm64" --push
