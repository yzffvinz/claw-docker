# OpenClaw 自定义镜像 - 更新至 2026.3.8
FROM alpine/openclaw:latest

USER root

# 修复飞书插件缺失的依赖（基础镜像漏了 @larksuiteoapi/node-sdk 及其依赖树）
# 用 cp -rn 避免覆盖已有的 symlink/目录
RUN mkdir -p /tmp/lark-fix && cd /tmp/lark-fix && \
    npm init -y > /dev/null 2>&1 && \
    npm install @larksuiteoapi/node-sdk && \
    cd /tmp/lark-fix/node_modules && \
    for pkg in *; do \
      [ "$pkg" = ".package-lock.json" ] && continue; \
      if [ ! -e "/app/node_modules/$pkg" ]; then \
        cp -r "$pkg" "/app/node_modules/$pkg"; \
      fi; \
    done && \
    for scope in @*/; do \
      [ ! -d "$scope" ] && continue; \
      mkdir -p "/app/node_modules/$scope"; \
      for pkg in ${scope}*/; do \
        spkg=$(basename "$pkg"); \
        if [ ! -e "/app/node_modules/${scope}${spkg}" ]; then \
          cp -r "$pkg" "/app/node_modules/${scope}${spkg}"; \
        fi; \
      done; \
    done && \
    rm -rf /tmp/lark-fix

# 安装 faster-whisper + ffmpeg 用于语音转文字
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip ffmpeg && \
    pip install --no-cache-dir --break-system-packages faster-whisper && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER node

# 预下载 base 模型（约150MB，构建时下载避免运行时等待）
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8')"
