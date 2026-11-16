# ==============================================================================
# Stage 1: Base PHP-FPM Image
# ==============================================================================
FROM php:8.4-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    sqlite-dev \
    netcat-openbsd

# Install official PHP extension installer helper
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install required PHP extensions for Laravel 13 & MySQL
RUN install-php-extensions \
    pdo_mysql \
    pdo_sqlite \
    bcmath \
    ctype \
    curl \
    dom \
    fileinfo \
    filter \
    gd \
    intl \
    mbstring \
    opcache \
    pcntl \
    session \
    tokenizer \
    xml \
    zip \
    redis

# Copy Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy PHP and OPcache configuration
COPY docker/php/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]

# ==============================================================================
# Stage 2: Frontend Asset Builder (Vite + Tailwind CSS)
# ==============================================================================
FROM node:22-alpine AS frontend-builder
WORKDIR /app

# Copy package manifests
COPY package.json package-lock.json* ./

# Install npm dependencies (ignore-scripts for security)
RUN npm install

# Copy frontend source files
COPY vite.config.js ./
COPY resources ./resources

# Build production assets into public/build
RUN npm run build

# ==============================================================================
# Stage 3: Composer Dependencies Builder
# ==============================================================================
FROM composer:2 AS composer-builder
WORKDIR /app

COPY composer.json composer.lock* ./

# Install production dependencies without dev packages and scripts
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

# ==============================================================================
# Stage 4: Development Target (for docker-compose local dev)
# ==============================================================================
FROM base AS development
ENV APP_ENV=local
ENV APP_DEBUG=true

# Keep user as root or www-data with proper entrypoint handling
EXPOSE 9000

# ==============================================================================
# Stage 5: Production Target (Self-contained, production-ready)
# ==============================================================================
FROM base AS production
ENV APP_ENV=production
ENV APP_DEBUG=false

# Copy application code
COPY . /var/www/html

# Copy pre-installed vendor and pre-built frontend assets
COPY --from=composer-builder /app/vendor /var/www/html/vendor
COPY --from=frontend-builder /app/public/build /var/www/html/public/build

# Set correct permissions for storage and bootstrap cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 9000
