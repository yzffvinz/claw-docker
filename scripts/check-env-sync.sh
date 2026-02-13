#!/bin/bash
# 检查 docker-compose.yml 中引用的环境变量是否都在 .env.example 中定义
set -euo pipefail

COMPOSE_VARS=$(grep -oP '\$\{\K\w+' docker-compose.yml | sort -u)
ENV_VARS=$(grep -oP '^\w+(?==)' .env.example | sort -u)

MISSING=""
for var in $COMPOSE_VARS; do
  if ! echo "$ENV_VARS" | grep -qx "$var"; then
    MISSING="$MISSING\n  - $var"
  fi
done

if [ -n "$MISSING" ]; then
  echo "❌ docker-compose.yml 引用了 .env.example 中缺失的变量:$MISSING"
  exit 1
fi

echo "✅ .env.example 与 docker-compose.yml 变量同步"
