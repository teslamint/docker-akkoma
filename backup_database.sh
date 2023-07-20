#!/usr/bin/env bash

set -eou pipefail
#set -x

BACKUPDIR=".dbbackup"
FILENAME="base"
RCLONE_REMOTE="nas"
REMOTEDIR="dbbackup"
COMPRESS="zstd"
EXT="zst"
DB_USER="pleroma"
BACKUP_FULLNAME="${FILENAME}.tar.${EXT}"

# check compressor exists
if [ "$(which $COMPRESS)" = "" ]; then
    echo "compressor $COMPRESS not found" > /dev/stderr
    exit 1
fi

# backup database
BASEPATH="${PWD}"
BACKUP_FULLPATH="${BASEPATH}/${BACKUPDIR}/${BACKUP_FULLNAME}"
docker compose exec -T postgres pg_basebackup -R -D - -F tar -U ${DB_USER} -X f | "${COMPRESS}" - -o "${BACKUP_FULLPATH}"

# upload to remote
DATE="$(TZ="Asia/Seoul" date +%Y-%m-%d)"
REMOTE_FULLPATH="${RCLONE_REMOTE}:/${REMOTEDIR}/${DATE}"
rclone copy ${BACKUP_FULLPATH} "${REMOTE_FULLPATH}/${BACKUP_FULLNAME}"
