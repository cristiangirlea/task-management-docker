#!/bin/sh
# Schedule backup.sh with cron. Cron jobs start with an empty environment, so
# the container's (database login, rclone settings) is saved for them.
set -eu

: "${BACKUP_SCHEDULE:=15 3 * * *}"

umask 077
export -p > /etc/backup.env
echo "$BACKUP_SCHEDULE . /etc/backup.env && /usr/local/bin/backup.sh > /proc/1/fd/1 2>&1" > /etc/crontabs/root

echo "backup: scheduled \"$BACKUP_SCHEDULE\" (UTC unless TZ is set), remote: ${BACKUP_REMOTE:-none}"
exec crond -f -l 8
