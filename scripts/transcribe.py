#!/usr/bin/env python3
"""语音转文字 - 使用 faster-whisper tiny 模型"""
import sys
from faster_whisper import WhisperModel

def transcribe(audio_path, language="zh"):
    model = WhisperModel("tiny", device="cpu", compute_type="int8")
    segments, info = model.transcribe(audio_path, language=language, beam_size=5)
    text = " ".join(seg.text.strip() for seg in segments)
    print(text)

if __name__ == "__main__":
    path = sys.argv[1]
    lang = sys.argv[2] if len(sys.argv) > 2 else "zh"
    transcribe(path, lang)
