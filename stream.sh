#!/bin/bash

set -Eeuo pipefail


# --------------------------------------------------
# Required YouTube stream key
# --------------------------------------------------

: "${YOUTUBE_STREAM_KEY:?Set YOUTUBE_STREAM_KEY before starting the container}"


# --------------------------------------------------
# Configuration
# --------------------------------------------------

WIDTH="${WIDTH:-720}"
HEIGHT="${HEIGHT:-1280}"
FPS="${FPS:-24}"

VIDEO_BITRATE="${VIDEO_BITRATE:-4000k}"
AUDIO_BITRATE="${AUDIO_BITRATE:-192k}"

YOUTUBE_URL="${YOUTUBE_URL:-rtmps://a.rtmp.youtube.com/live2}"


# PulseAudio monitor containing Chromium audio
AUDIO_SOURCE="${AUDIO_SOURCE:-stream_sink.monitor}"


# --------------------------------------------------
# FFmpeg
# --------------------------------------------------

exec ffmpeg \
    -hide_banner \
    -loglevel warning \
    \
    -f x11grab \
    -video_size "${WIDTH}x${HEIGHT}" \
    -framerate "${FPS}" \
    -draw_mouse 0 \
    -i "${DISPLAY}.0+0,0" \
    \
    -f pulse \
    -ar 44100 \
    -ac 2 \
    -i "${AUDIO_SOURCE}" \
    \
    -map 0:v:0 \
    -map 1:a:0 \
    \
    -c:v libx264 \
    -preset "${X264_PRESET:-ultrafast}" \
    -tune zerolatency \
    -pix_fmt yuv420p \
    -r "${FPS}" \
    \
    -b:v "${VIDEO_BITRATE}" \
    -minrate "${VIDEO_BITRATE}" \
    -maxrate "${VIDEO_BITRATE}" \
    -bufsize 8000k \
    \
    -g $((FPS * 2)) \
    -keyint_min $((FPS * 2)) \
    -sc_threshold 0 \
    \
    -profile:v main \
    \
    -c:a aac \
    -b:a "${AUDIO_BITRATE}" \
    -ar 44100 \
    -ac 2 \
    \
    -f flv \
    "${YOUTUBE_URL}/${YOUTUBE_STREAM_KEY}"