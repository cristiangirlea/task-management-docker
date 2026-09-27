# syntax=docker/dockerfile:1
# Laravel API (php-fpm).
#
# The build context is the Laravel repo itself (docker-compose.yml points here
# via STACK_DIR). Dockerfile.dockerignore next to this file keeps vendor/, .env,
# node_modules/ and tests out of the image.
FROM php:8.4-fpm-alpine

# bash: the app's entrypoint.sh is a bash script. git/unzip: used by Composer.
RUN apk add --no-cache bash git unzip

# PHP extensions via https://github.com/mlocati/docker-php-extension-installer,
# which pulls in the right Alpine build/runtime packages for each one.
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_pgsql pgsql zip bcmath opcache redis

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    && chown -R www-data:www-data storage bootstrap/cache

# php-fpm listens on 9000 (the base image's default); nginx reaches it over the
# compose network, the port is never published on the host.
EXPOSE 9000

# The repo's own entrypoint: clears caches, runs migrations, seeds when
# SEED_DATABASE=true, then starts php-fpm. Invoked through bash because the
# file is committed without the executable bit.
CMD ["bash", "/var/www/html/entrypoint.sh"]
