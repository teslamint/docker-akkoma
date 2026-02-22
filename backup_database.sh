#!/usr/bin/env bash

set -eou pipefail
#set -x

BASEPATH="${PWD}"
BACKUPDIR=".dbbackup"
FILENAME="base"
RCLONE_REMOTE="${RCLONE_REMOTE:-nas}"
REMOTEDIR="${REMOTEDIR:-dbbackup}"
COMPRESS="${COMPRESS:-zstd}"
EXT="${EXT:-zst}"
DB_USER="${DB_USER:-pleroma}"
BACKUP_FULLNAME="${FILENAME}.tar.${EXT}"
DATE="$(TZ="${TZ:-Asia/Seoul}" date +%Y-%m-%d)"
BACKUP_FULLPATH="${BASEPATH}/${BACKUPDIR}/${BACKUP_FULLNAME}"
REMOTE_FULLPATH="${RCLONE_REMOTE}:/${REMOTEDIR}/${DATE}"
BACKUP_DATE_PATH="${BASEPATH}/${BACKUPDIR}/${DATE}"

if [ -e "${BACKUP_DATE_PATH}/${BACKUP_FULLNAME}" ]; then
    echo "backup already exists. exiting."
    exit 0
fi

# check compressor exists
if ! command -v "${COMPRESS}" > /dev/null 2>&1; then
    echo "compressor ${COMPRESS} not found" > /dev/stderr
    exit 1
fi

# backup database
if [ ! -e "${BACKUP_FULLPATH}" ]; then
    docker compose exec -T postgres pg_basebackup -R -D - -F tar -U "${DB_USER}" -X f | "${COMPRESS}" - -o "${BACKUP_FULLPATH}.tmp"
    mv "${BACKUP_FULLPATH}.tmp" "${BACKUP_FULLPATH}"
fi

# upload to remote
rclone copy "${BACKUP_FULLPATH}" "${REMOTE_FULLPATH}"

# rename backup file
mkdir -p "${BACKUP_DATE_PATH}"
mv "${BACKUP_FULLPATH}" "${BACKUP_DATE_PATH}/${BACKUP_FULLNAME}"

# cleanup old backup over 7 days
find "${BACKUPDIR}/" -type f -name "${BACKUP_FULLNAME}" -atime +6 -exec rm -f {} \;
find "${BACKUPDIR}/" -type d -empty -exec rmdir -f {} \;
