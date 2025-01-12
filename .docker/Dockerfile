# Use PHP 8.4 with Apache
FROM php:8.4-apache

# Install necessary PHP extensions (Xdebug, PDO, etc.)
RUN apt-get update && apt-get install -y libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Enable Apache mod_rewrite for .htaccess support
RUN a2enmod rewrite

# Copy project files into the container
COPY .. /var/www/html/

# Set the working directory
WORKDIR /var/www/html/

# Expose port 80 for the web server
EXPOSE 80
