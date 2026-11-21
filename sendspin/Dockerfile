# syntax=docker/dockerfile:1.7
# Multi-stage build of sendspin-cpp-cli with the native PulseAudio backend
# only. PortAudio and PipeWire stay off so the runtime image stays small.

ARG DEBIAN_VERSION=trixie-slim

FROM debian:${DEBIAN_VERSION} AS build

ARG SENDSPIN_CLI_REF=v1.0.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      git \
      libasound2-dev \
      libpulse-dev \
      pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 --branch "${SENDSPIN_CLI_REF}" \
      https://github.com/Sendspin/sendspin-cpp-cli.git . \
 && git rev-parse --verify HEAD > /tmp/sendspin-cli.sha

# Upstream auto-detects backends. OFF drops PortAudio/PipeWire/mDNS/TUI.
# The greps fail the build if configure silently drops Pulse.
RUN cmake -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DSENDSPIN_CLI_WITH_ALSA=ON \
      -DSENDSPIN_CLI_WITH_PORTAUDIO=OFF \
      -DSENDSPIN_CLI_WITH_PULSE=ON \
      -DSENDSPIN_CLI_WITH_PIPEWIRE=OFF \
      -DSENDSPIN_CLI_WITH_MDNS=OFF \
      -DSENDSPIN_CLI_WITH_TUI=OFF \
      -DSENDSPIN_CLI_BUILD_TESTS=OFF \
    | tee /tmp/configure.log \
 && grep -qE 'sendspin-cli audio backends:.*\bpulse\b' /tmp/configure.log \
 && grep -qE 'sendspin-cli audio backends:.*\balsa\b' /tmp/configure.log \
 && ! grep -qE 'sendspin-cli audio backends:.*\bpipewire\b' /tmp/configure.log \
 && ! grep -qE 'sendspin-cli audio backends:.*\bportaudio\b' /tmp/configure.log

RUN cmake --build build -j"$(nproc)" \
 && DESTDIR=/stage cmake --install build --component sendspin-cli \
 && mkdir -p /stage/usr/local/share/sendspin-cli \
 && core_tag="$(sed -n 's/^set(SENDSPIN_GIT_TAG "\([^"]*\)".*/\1/p' CMakeLists.txt)" \
 && test -n "${core_tag}" \
 && printf 'SENDSPIN_CLI_REF=%s\nSENDSPIN_CLI_SHA=%s\nSENDSPIN_GIT_TAG=%s\n' \
      "${SENDSPIN_CLI_REF}" "$(cat /tmp/sendspin-cli.sha)" "${core_tag}" \
      > /stage/usr/local/share/sendspin-cli/BUILD-INFO.txt


FROM debian:${DEBIAN_VERSION}

ARG SENDSPIN_CLI_REF=v1.0.1

LABEL org.opencontainers.image.source="https://github.com/howels/pipewire-sendspin-squeezelite-containers" \
      org.opencontainers.image.title="sendspin" \
      org.opencontainers.image.description="sendspin-cpp-cli player linked to a shared PulseAudio socket" \
      org.opencontainers.image.version="${SENDSPIN_CLI_REF}"

# Runtime: native Pulse client + pactl for the entrypoint readiness check.
# libasound2 is linked because ALSA stays in the build for -o alsa:pulse fallback.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libasound2t64 \
      libpulse0 \
      libstdc++6 \
      pulseaudio-utils \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 1000 sendspin \
 && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin sendspin

COPY --from=build /stage/usr/local/bin/sendspin-cli /usr/local/bin/sendspin-cli
COPY --from=build /stage/usr/local/share/sendspin-cli/BUILD-INFO.txt \
                  /usr/local/share/sendspin-cli/BUILD-INFO.txt
COPY client.conf /etc/pulse/client.conf
COPY entrypoint.sh /usr/local/bin/sendspin-entrypoint
RUN chmod 755 /usr/local/bin/sendspin-entrypoint \
 && ln -s sendspin-cli /usr/local/bin/sendspin

USER 1000:1000
ENV HOME=/home/sendspin \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=unix:/run/pulse/runtime/native \
    SENDSPIN_OUTPUT=pulse

ENTRYPOINT ["/usr/local/bin/sendspin-entrypoint"]
CMD ["--name", "sendspin", "--output", "pulse"]
