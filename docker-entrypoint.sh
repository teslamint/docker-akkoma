#!/bin/ash

set -e

DB_WAIT_TIMEOUT=${DB_WAIT_TIMEOUT:-60}
_db_wait_count=0

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:${DB_PORT:-5432}/${DB_NAME:-pleroma} -t 1; do
    _db_wait_count=$((_db_wait_count + 1))
    if [ $_db_wait_count -ge $DB_WAIT_TIMEOUT ]; then
        echo "ERROR: Database did not become ready within ${DB_WAIT_TIMEOUT} seconds" >&2
        exit 1
    fi
    sleep 1s
done

echo "-- Running migrations..."
if ! $HOME/bin/pleroma_ctl migrate; then
    echo "ERROR: Database migration failed" >&2
    exit 1
fi

echo "-- Starting!"
exec $HOME/bin/pleroma foreground
