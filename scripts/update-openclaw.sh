#!/bin/sh
# 拉取最新 openclaw 镜像并重启容器
set -e
cd "$(dirname "$0")/.."

echo "Pulling latest openclaw image..."
docker compose pull openclaw

echo "Restarting openclaw container..."
docker compose up -d --no-deps openclaw

echo "Done. Container status:"
docker compose ps openclaw
