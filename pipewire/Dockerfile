# syntax=docker/dockerfile:1.29
# PipeWire provides the graph; pipewire-pulse keeps the PulseAudio Unix
# socket API that sendspin, squeezelite, and MoonLight already use.
# Alpine 3.22 ships PipeWire 1.4.x (newer than Debian trixie's 1.4.2).

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
      pipewire \
      pipewire-pulse \
      wireplumber \
      pulseaudio-utils \
 && addgroup -g 1000 player \
 && adduser -D -u 1000 -G player -h /home/player player

COPY pipewire.conf.d/ /etc/pipewire/pipewire.conf.d/
COPY pipewire-pulse.conf.d/ /etc/pipewire/pipewire-pulse.conf.d/
COPY entrypoint.sh /usr/local/bin/pipewire-entrypoint
# /run/pulse is an emptyDir in Kubernetes; create it here so a bare
# `podman run` without a volume still starts.
RUN chmod 755 /usr/local/bin/pipewire-entrypoint \
 && mkdir -p /run/pulse/runtime \
 && chown -R 1000:1000 /run/pulse

USER 1000:1000
ENV HOME=/home/player \
    XDG_RUNTIME_DIR=/run/pulse/runtime \
    PULSE_RUNTIME_PATH=/run/pulse/runtime \
    PULSE_SERVER=unix:/run/pulse/runtime/native

LABEL org.opencontainers.image.source="https://github.com/howels/pipewire-sendspin-squeezelite-containers" \
      org.opencontainers.image.title="pipewire" \
      org.opencontainers.image.description="PipeWire with pipewire-pulse null sink sendspin for shared-socket clients"

ENTRYPOINT ["/usr/local/bin/pipewire-entrypoint"]
CMD ["serve"]
