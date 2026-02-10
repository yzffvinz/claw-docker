#!/bin/sh
# 重启所有容器
set -e
cd "$(dirname "$0")/.."

echo "Stopping all containers..."
docker compose down

echo "Starting all containers..."
docker compose up -d

echo "Done. Container status:"
docker compose ps
