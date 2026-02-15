#!/bin/sh
# 更新所有服务：拉取最新代码和镜像，重建并启动容器
set -e
cd "$(dirname "$0")/.."

echo "=== Pulling latest code ==="
git pull

echo ""
echo "=== Pulling latest images ==="
docker compose pull

echo ""
echo "=== Recreating containers ==="
docker compose up -d --remove-orphans

echo ""
echo "=== Cleaning up old images ==="
docker image prune -f

echo ""
echo "=== Container status ==="
docker compose ps

echo ""
echo "Done. All services updated."
