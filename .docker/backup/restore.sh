#!/bin/sh
# List or restore database dumps.
#
#   restore.sh                list local and off-site dumps
#   restore.sh <dump>         restore it: a path, a file name in /backups, or
#                             a file name in BACKUP_REMOTE (downloaded first)
#
# Restores into PGDATABASE, or RESTORE_DATABASE if set, replacing the objects
# it contains. Stop the app first when restoring over the live database.
set -eu

dir=${BACKUP_DIR:-/backups}

if [ $# -eq 0 ]; then
    echo "Local ($dir):"
    ls -1t "$dir"/*.dump 2>/dev/null | xargs -r -n1 basename || true
    if [ -n "${BACKUP_REMOTE:-}" ]; then
        echo "Off-site ($BACKUP_REMOTE):"
        rclone -q lsf --include '*.dump' "$BACKUP_REMOTE" | sort -r
    fi
    exit 0
fi

src=$1
if [ ! -f "$src" ] && [ -f "$dir/$src" ]; then
    src="$dir/$src"
elif [ ! -f "$src" ]; then
    : "${BACKUP_REMOTE:?no such local dump, and BACKUP_REMOTE is not set}"
    rclone -q copyto "$BACKUP_REMOTE/$1" "/tmp/$1"
    src="/tmp/$1"
fi

target=${RESTORE_DATABASE:-$PGDATABASE}
echo "restore: $src -> database $target"
pg_restore --clean --if-exists --no-owner --dbname="$target" "$src"
echo "restore: done"
