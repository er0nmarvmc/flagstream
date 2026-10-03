#!/bin/bash

set -Eeuo pipefail

WIDTH="${WIDTH:-720}"
HEIGHT="${HEIGHT:-1280}"
FPS="${FPS:-30}"

DISPLAY_NUM="${DISPLAY_NUM:-99}"

export DISPLAY=":${DISPLAY_NUM}"
export PULSE_SERVER="unix:/tmp/pulse/native"
export PULSE_SINK="stream_sink"

mkdir -p /tmp/pulse
mkdir -p /tmp/chromium-profile

cleanup() {
    set +e

    kill "${FFMPEG_PID:-}" 2>/dev/null || true
    kill "${CHROMIUM_PID:-}" 2>/dev/null || true
    kill "${HTTP_PID:-}" 2>/dev/null || true
    kill "${XVFB_PID:-}" 2>/dev/null || true
    kill "${WATCHDOG_PID:-}" 2>/dev/null || true
    kill "${PULSE_PID:-}" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

echo "[xvfb] Starting virtual display..."

Xvfb "$DISPLAY" \
    -screen 0 "${WIDTH}x${HEIGHT}x24" \
    -ac \
    +extension GLX \
    +render \
    -noreset \
    >/tmp/xvfb.log 2>&1 &

XVFB_PID=$!

sleep 2

if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "[xvfb] Failed to start"
    cat /tmp/xvfb.log
    exit 1
fi

echo "[xvfb] Display ${DISPLAY} is running"

echo "[audio] Starting PulseAudio..."

pulseaudio \
    --daemonize=no \
    --exit-idle-time=-1 \
    --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse/native" \
    --load="module-null-sink sink_name=stream_sink sink_properties=device.description=StreamSink" \
    >/tmp/pulse.log 2>&1 &

PULSE_PID=$!

sleep 3

echo "[web] Starting HTTP server..."

cd /app

python3 -m http.server 8080 \
    --bind 127.0.0.1 \
    >/tmp/http.log 2>&1 &

HTTP_PID=$!

sleep 2

if ! kill -0 "$HTTP_PID" 2>/dev/null; then
    echo "[web] HTTP server failed"
    cat /tmp/http.log
    exit 1
fi

echo "[web] Game available at http://127.0.0.1:8080/"

start_chromium() {

    rm -rf /tmp/chromium-profile
    mkdir -p /tmp/chromium-profile

    echo "[browser] Starting Chromium..."

    chromium \
        --disable-dev-shm-usage \
        --disable-gpu \
        --autoplay-policy=no-user-gesture-required \
        --test-type \
        --enable-speech-dispatcher \
        --window-size="${WIDTH},${HEIGHT}" \
        --window-position=0,0 \
        --force-device-scale-factor=1 \
        --hide-scrollbars \
        --disable-features=Translate,BackForwardCache \
        --disable-background-timer-throttling \
        --disable-renderer-backgrounding \
        --disable-backgrounding-occluded-windows \
        --user-data-dir=/tmp/chromium-profile \
        --app=http://127.0.0.1:8080/ \
        >/tmp/chromium.log 2>&1 &

    CHROMIUM_PID=$!

    echo "[browser] Chromium PID: ${CHROMIUM_PID}"
}

start_chromium

sleep 5

if ! kill -0 "$CHROMIUM_PID" 2>/dev/null; then
    echo "[browser] Chromium failed to start"
    cat /tmp/chromium.log
    exit 1
fi

echo "[browser] Chromium is running"

(
    while true; do

        if ! kill -0 "$CHROMIUM_PID" 2>/dev/null; then

            echo "[browser] Chromium exited; restarting in 3 seconds..."

            sleep 3

            start_chromium

            sleep 5

        fi

        sleep 3
    done

) &

WATCHDOG_PID=$!

while true; do

    echo "[stream] Starting FFmpeg..."

    /app/stream.sh &

    FFMPEG_PID=$!

    wait "$FFMPEG_PID" || true

    echo "[stream] FFmpeg exited; restarting in 5 seconds..."

    sleep 5

done