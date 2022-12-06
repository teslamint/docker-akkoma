#!/usr/bin/env bash
set -x
#set -e
set -u
set -o pipefail

BRANCH=develop
COMMIT_HASH=$(curl "https://akkoma.dev/api/v1/repos/AkkomaGang/akkoma/branches/$BRANCH" | jq -r '.commit.id')
COMMIT_ID=${COMMIT_HASH:-$BRANCH}

# check image already built
docker pull teslamint/akkoma:${BRANCH} || true
docker pull teslamint/akkoma:${COMMIT_ID} || true

docker buildx build --rm -t teslamint/akkoma:latest -t teslamint/akkoma:${BRANCH} -t teslamint/akkoma:${COMMIT_ID} . --build-arg "PLEROMA_VER=$COMMIT_ID" --platform=linux/amd64,linux/arm64 --push
