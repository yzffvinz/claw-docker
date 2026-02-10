#!/bin/sh
# 清理不用的 Docker 镜像、停止的容器、未使用的网络和卷，以及容器日志
set -e
cd "$(dirname "$0")/.."

echo "=== Cleaning up stopped containers ==="
docker container prune -f

echo ""
echo "=== Cleaning up dangling images ==="
docker image prune -f

echo ""
echo "=== Cleaning up unused networks ==="
docker network prune -f

echo ""
echo "=== Truncating container logs ==="
for id in $(docker compose ps -q 2>/dev/null); do
  log_file=$(docker inspect --format='{{.LogPath}}' "$id" 2>/dev/null)
  if [ -n "$log_file" ] && [ -f "$log_file" ]; then
    truncate -s 0 "$log_file"
    name=$(docker inspect --format='{{.Name}}' "$id" | sed 's/^\///')
    echo "  Cleared log for $name"
  fi
done

echo ""
echo "=== Disk usage summary ==="
docker system df

echo ""
echo "Done."
