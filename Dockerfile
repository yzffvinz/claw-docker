FROM alpine/openclaw:latest

USER root

# 修复飞书插件缺失的依赖（基础镜像漏了这些）
RUN mkdir -p /tmp/lark-fix && cd /tmp/lark-fix && \
    npm init -y > /dev/null 2>&1 && \
    npm install @larksuiteoapi/node-sdk && \
    cp -r /tmp/lark-fix/node_modules/@larksuiteoapi /app/node_modules/ && \
    cp -r /tmp/lark-fix/node_modules/axios /app/node_modules/ && \
    cp -r /tmp/lark-fix/node_modules/proxy-from-env /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/follow-redirects /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/form-data /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/mime-types /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/mime-db /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/combined-stream /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/delayed-stream /app/node_modules/ 2>/dev/null; \
    cp -r /tmp/lark-fix/node_modules/asynckit /app/node_modules/ 2>/dev/null; \
    rm -rf /tmp/lark-fix

# 安装 faster-whisper + ffmpeg 用于语音转文字
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip ffmpeg && \
    pip install --no-cache-dir --break-system-packages faster-whisper && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER node

# 预下载 base 模型（约150MB，构建时下载避免运行时等待）
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8')"
