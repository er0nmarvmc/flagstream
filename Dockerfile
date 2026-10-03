FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV PULSE_SERVER=unix:/tmp/pulse/native
ENV HOME=/home/streamer

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-sandbox \
    ffmpeg \
    pulseaudio \
    espeak-ng \
    speech-dispatcher \
    speech-dispatcher-espeak-ng \
    xvfb \
    python3 \
    ca-certificates \
    fonts-noto-color-emoji \
    fonts-dejavu \
    fonts-liberation \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY index.html /app/index.html
COPY music.mp3 /app/music.mp3
COPY win.mp3 /app/win.mp3
COPY collide.mp3 /app/collide.mp3
COPY start.sh /app/start.sh
COPY stream.sh /app/stream.sh

RUN chmod +x /app/start.sh /app/stream.sh && \
    useradd --create-home --uid 10001 streamer && \
    chown -R streamer:streamer /app /tmp

USER streamer

EXPOSE 8080

ENTRYPOINT ["/app/start.sh"]