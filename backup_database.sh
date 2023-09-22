#!/usr/bin/env bash

set -eou pipefail
#set -x

BASEPATH="${PWD}"
BACKUPDIR=".dbbackup"
FILENAME="base"
RCLONE_REMOTE="nas"
REMOTEDIR="dbbackup"
COMPRESS="zstd"
EXT="zst"
DB_USER="pleroma"
BACKUP_FULLNAME="${FILENAME}.tar.${EXT}"
DATE="$(TZ="Asia/Seoul" date +%Y-%m-%d)"
BACKUP_FULLPATH="${BASEPATH}/${BACKUPDIR}/${BACKUP_FULLNAME}"
REMOTE_FULLPATH="${RCLONE_REMOTE}:/${REMOTEDIR}/${DATE}"
BACKUP_DATE_PATH="${BASEPATH}/${BACKUPDIR}/${DATE}"

if [ -e "${BACKUP_DATE_PATH}/${BACKUP_FULLNAME}" ]; then
    echo "backup already exists. exiting."
    exit 0
fi

# check compressor exists
if [ "$(which $COMPRESS)" = "" ]; then
    echo "compressor $COMPRESS not found" > /dev/stderr
    exit 1
fi

# backup database
if [ ! -e "${BACKUP_FULLPATH}" ]; then
    docker compose exec -T postgres pg_basebackup -R -D - -F tar -U ${DB_USER} -X f | "${COMPRESS}" - -o "${BACKUP_FULLPATH}"
fi

# upload to remote
rclone copy "${BACKUP_FULLPATH}" "${REMOTE_FULLPATH}/${BACKUP_FULLNAME}"

# rename backup file
mkdir -p "${BACKUP_DATE_PATH}"
mv "${BACKUP_FULLPATH}" "${BACKUP_DATE_PATH}/${BACKUP_FULLNAME}"
