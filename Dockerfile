FROM alpine/openclaw:latest

# 安装 faster-whisper + ffmpeg 用于语音转文字
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip ffmpeg && \
    pip install --no-cache-dir --break-system-packages faster-whisper && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
USER node

# 预下载 tiny 模型（约75MB，构建时下载避免运行时等待）
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('tiny', device='cpu', compute_type='int8')"
