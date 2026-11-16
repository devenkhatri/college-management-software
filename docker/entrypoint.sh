#!/bin/sh
set -e

# Ensure required Laravel storage and cache directories exist
mkdir -p /var/www/html/storage/app/public \
         /var/www/html/storage/framework/cache/data \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

# Fix ownership and permissions for web server access (directories 775, files 664)
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
find /var/www/html/storage /var/www/html/bootstrap/cache -type d -exec chmod 775 {} + 2>/dev/null || true
find /var/www/html/storage /var/www/html/bootstrap/cache -type f -exec chmod 664 {} + 2>/dev/null || true

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

# Generate application key if not set (using shared lock to avoid concurrent execution)
if [ -f /var/www/html/.env ] && ! grep -q '^APP_KEY=base64:' /var/www/html/.env; then
    if mkdir /var/www/html/storage/.key_gen.lock 2>/dev/null; then
        echo "Generating application encryption key..."
        php artisan key:generate --force || true
        rm -rf /var/www/html/storage/.key_gen.lock
    fi
fi

# Execute passed command (default: php-fpm)
exec "$@"
