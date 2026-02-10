#!/bin/sh
# ============================================
# OpenClaw 容器启动初始化脚本
# 在 OpenClaw 启动前执行，用于配置容器内环境
# ============================================

set -e

WORKSPACE="/home/node/.openclaw/workspace"

# ----------------------------------------
# 1. Notion API Key
# ----------------------------------------
if [ -n "$NOTION_API_KEY" ]; then
  mkdir -p /home/node/.config/notion
  echo "$NOTION_API_KEY" > /home/node/.config/notion/api_key
  echo "[init] ✅ Notion API Key configured"
fi

# ----------------------------------------
# 2. Git 凭证（workspace 自动备份）
# ----------------------------------------
if [ -n "$GITHUB_PAT" ] && [ -d "$WORKSPACE/.git" ]; then
  # 更新 remote URL 中的 PAT
  CURRENT_URL=$(cd "$WORKSPACE" && git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$CURRENT_URL" ]; then
    # 提取 repo 路径（去掉协议和认证信息）
    REPO_PATH=$(echo "$CURRENT_URL" | sed 's|https://[^/]*@github.com/|github.com/|; s|https://github.com/|github.com/|')
    # 提取用户名
    USERNAME=$(echo "$REPO_PATH" | cut -d'/' -f2)
    REPO=$(echo "$REPO_PATH" | cut -d'/' -f3)
    NEW_URL="https://${USERNAME}:${GITHUB_PAT}@${REPO_PATH}"
    cd "$WORKSPACE" && git remote set-url origin "$NEW_URL"
    echo "[init] ✅ Git remote updated with fresh PAT"
  fi
fi

echo "[init] ✅ Initialization complete"
