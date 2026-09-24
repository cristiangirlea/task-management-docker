#!/bin/sh
# Dump the database to /backups, then copy the dump off-site when
# BACKUP_REMOTE is set (an rclone path such as "offsite:my-bucket/task-board").
#
#   BACKUP_KEEP_LOCAL   dumps kept on this server (default 7)
#   BACKUP_KEEP_DAYS    days kept off-site (default 14)
set -eu

dir=${BACKUP_DIR:-/backups}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
file="$dir/${PGDATABASE}-${stamp}.dump"

# Custom format: compressed, and pg_restore can restore it selectively.
pg_dump --format=custom --no-owner --file="$file.partial"
mv "$file.partial" "$file"
echo "backup: wrote $file ($(du -h "$file" | cut -f1))"

ls -1t "$dir"/*.dump | tail -n +$((${BACKUP_KEEP_LOCAL:-7} + 1)) | xargs -r rm -f

if [ -z "${BACKUP_REMOTE:-}" ]; then
    echo "backup: BACKUP_REMOTE is not set, so this dump exists only on this server" >&2
    exit 0
fi

rclone -q copy "$file" "$BACKUP_REMOTE"
rclone -q delete --min-age "${BACKUP_KEEP_DAYS:-14}d" --include '*.dump' "$BACKUP_REMOTE"
echo "backup: copied to $BACKUP_REMOTE"
