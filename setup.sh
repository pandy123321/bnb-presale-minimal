#!/bin/bash
# BNB Presale - Development Environment Setup
# Run this script after Docker Desktop is installed and running.

set -e

echo "=== BNB Presale Setup ==="

# 1. Copy .env
if [ ! -f backend/.env ] || [ ! -s backend/.env ]; then
    echo "[1/6] Creating .env from .env.example..."
    cp backend/.env.example backend/.env
fi

# 2. Start Docker containers
echo "[2/6] Starting Docker containers..."
docker compose up -d --build

# 3. Wait for postgres
echo "[3/6] Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U bnb -d bnb_presale 2>/dev/null; do
    sleep 2
done
echo "PostgreSQL is ready."

# 4. Install Composer dependencies
echo "[4/6] Installing Composer dependencies..."
docker compose exec -T php composer install --no-interaction

# 5. Generate app key
echo "[5/6] Generating application key..."
docker compose exec -T php php artisan key:generate

# 6. Run migrations and seed
echo "[6/6] Running migrations and seeding..."
docker compose exec -T php php artisan migrate --force
docker compose exec -T php php artisan db:seed --force

echo ""
echo "=== Setup Complete ==="
echo ""
echo "API is available at: http://localhost:8080/api"
echo "Health check:        http://localhost:8080/up"
echo "Anvil RPC:           http://localhost:8545"
echo ""
echo "Default admin login:"
echo "  Email:    admin@bnb-presale.local"
echo "  Password: admin123"
echo ""
echo "To stop:  docker compose down"
echo "To start: docker compose up -d"
