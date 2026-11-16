#!/bin/sh
set -e

# Ensure required Laravel storage and cache directories exist
mkdir -p /var/www/html/storage/app/public \
         /var/www/html/storage/framework/cache/data \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

# Fix ownership and permissions for web server access
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# Initialize .env if missing
if [ ! -f /var/www/html/.env ]; then
    if [ -f /var/www/html/.env.docker ]; then
        echo "Creating .env from .env.docker..."
        cp /var/www/html/.env.docker /var/www/html/.env
    elif [ -f /var/www/html/.env.docker.example ]; then
        echo "Creating .env from .env.docker.example..."
        cp /var/www/html/.env.docker.example /var/www/html/.env
    elif [ -f /var/www/html/.env.example ]; then
        echo "Creating .env from .env.example..."
        cp /var/www/html/.env.example /var/www/html/.env
    fi
fi

# Generate application key if not set
if [ -f /var/www/html/.env ] && [ -z "$(grep '^APP_KEY=' /var/www/html/.env | cut -d '=' -f2)" ]; then
    echo "Generating application encryption key..."
    php artisan key:generate --force || true
fi

# Execute passed command (default: php-fpm)
exec "$@"
