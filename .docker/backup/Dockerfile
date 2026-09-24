# Nightly database backups for the production stack.
# pg_dump matches the server (Postgres 16); rclone copies dumps off-site.
FROM alpine:3.20

RUN apk add --no-cache postgresql16-client rclone tzdata

COPY entrypoint.sh backup.sh restore.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/backup.sh /usr/local/bin/restore.sh

ENTRYPOINT ["entrypoint.sh"]
