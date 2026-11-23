# syntax=docker/dockerfile:1.7
# Build ralph-irving/squeezelite with PulseAudio output on Alpine, then copy
# the single binary into a runtime image with only the shared libraries it needs.

ARG ALPINE_VERSION=3.24

FROM alpine:${ALPINE_VERSION} AS build

ARG SQUEEZELITE_REF=b02a9ac77794c9914fa2b70caa98010e9f23cc2d

RUN apk add --no-cache \
      build-base \
      flac-dev \
      git \
      lame-dev \
      libmad-dev \
      libvorbis-dev \
      mpg123-dev \
      openssl-dev \
      pulseaudio-dev \
      soxr-dev

WORKDIR /src

RUN git clone --filter=blob:none https://github.com/ralph-irving/squeezelite.git . \
 && git checkout --detach "${SQUEEZELITE_REF}"

# LINKALL pulls codecs in statically against the Alpine shared libs we ship.
# PULSEAUDIO enables -o pulse. RESAMPLE/SSL/DSD match a useful LMS client.
RUN make -j"$(nproc)" \
      OPTS="-DLINKALL -DRESAMPLE -DDSD -DUSE_SSL -DPULSEAUDIO -DNO_FAAD" \
 && strip squeezelite \
 && ./squeezelite -? >/dev/null


FROM alpine:${ALPINE_VERSION}

ARG SQUEEZELITE_REF=b02a9ac77794c9914fa2b70caa98010e9f23cc2d

LABEL org.opencontainers.image.source="https://github.com/howels/pipewire-sendspin-squeezelite-containers" \
      org.opencontainers.image.title="squeezelite" \
      org.opencontainers.image.description="squeezelite player linked to a shared PulseAudio socket" \
      org.opencontainers.image.revision="${SQUEEZELITE_REF}"

RUN apk add --no-cache \
      flac-libs \
      lame-libs \
      libmad \
      libogg \
      libvorbis \
      mpg123-libs \
      libssl3 \
      libcrypto3 \
      soxr \
      libpulse \
      pulseaudio-utils \
 && addgroup -g 1000 squeezelite \
 && adduser -D -u 1000 -G squeezelite -h /home/squeezelite squeezelite

COPY --from=build /src/squeezelite /usr/local/bin/squeezelite
COPY client.conf /etc/pulse/client.conf
COPY entrypoint.sh /usr/local/bin/squeezelite-entrypoint
RUN chmod 755 /usr/local/bin/squeezelite-entrypoint

USER 1000:1000
ENV HOME=/home/squeezelite \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=unix:/run/pulse/runtime/native \
    SQUEEZELITE_OUTPUT=default

ENTRYPOINT ["/usr/local/bin/squeezelite-entrypoint"]
CMD ["-n", "squeezelite", "-o", "default"]
