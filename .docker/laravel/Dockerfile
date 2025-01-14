FROM php:8.4-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    zip unzip git curl libpq-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /var/www/html

# Copy the full Laravel application
COPY . /var/www/html/

# Install Composer globally
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Run composer install (now that artisan is present)
RUN composer install --no-dev --optimize-autoloader

# Set permissions for storage and bootstrap cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Copy the entrypoint script and set permissions
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose the PHP-FPM port
EXPOSE 8000

# Use entrypoint script to handle migrations and PHP-FPM start
CMD ["/usr/local/bin/entrypoint.sh"]
