#!/bin/sh
# Dev-stack entrypoint for the Laravel container (bind-mounted by compose).
#
# The repo is mounted over /var/www/html, which hides the vendor/ directory
# baked into the image. Install dependencies when they are missing, then hand
# over to the command: by default the repo's own entrypoint.sh (migrations,
# seeding, php-fpm), or whatever was passed to `docker compose run app ...`.
set -e

cd /var/www/html

if [ ! -f vendor/autoload.php ]; then
    echo "vendor/ is missing, running composer install (first start takes a while)..."
    composer install --no-interaction --prefer-dist
fi

exec "$@"
