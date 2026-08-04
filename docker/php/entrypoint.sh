#!/bin/sh
set -e

cd /var/www

# 1. 先准备 .env 和 APP_KEY —— 必须在 composer install 之前，
#    Laravel 的 post-install 脚本（package:discover）依赖它们，否则 composer install 会崩
if [ ! -f .env ]; then
    echo "[entrypoint] creating .env from .env.example"
    cp .env.example .env
fi
if ! grep -q '^APP_KEY=base64:' .env; then
    echo "[entrypoint] generating app key"
    php artisan key:generate --force
fi

# 2. 安装 composer 依赖（--no-scripts 跳过会依赖 DB/环境的 artisan 脚本）
if [ ! -f vendor/autoload.php ]; then
    echo "[entrypoint] composer install..."
    # --no-dev：跳过 sail/tinker 等 dev 依赖，避开与 Laravel 13 的版本冲突，且生产不装开发工具
    composer install --no-dev --no-interaction --no-progress --no-scripts
    echo "[entrypoint] rebuilding autoloader + running package scripts"
    composer dump-autoload --optimize
else
    echo "[entrypoint] vendor present, skip composer install"
fi

# 3. 执行迁移
echo "[entrypoint] running migrations..."
php artisan migrate --force

# 4. 启动 php-fpm
echo "[entrypoint] starting php-fpm..."
exec php-fpm
