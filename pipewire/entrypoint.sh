#!/bin/sh
set -eu

wait_for_server() {
  i=0
  while ! pactl info >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -gt 150 ]; then
      echo "timed out waiting for PipeWire Pulse socket at ${PULSE_SERVER}" >&2
      exit 1
    fi
    sleep 0.2
  done
}

wait_for_sink() {
  i=0
  while ! pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -qx sendspin; do
    i=$((i + 1))
    if [ "$i" -gt 150 ]; then
      echo "timed out waiting for null sink sendspin" >&2
      pactl list sinks short >&2 || true
      exit 1
    fi
    sleep 0.2
  done
}

start_pipewire() {
  mkdir -p /run/pulse/runtime
  chmod 700 /run/pulse/runtime
  export HOME=/home/player
  export XDG_RUNTIME_DIR=/run/pulse/runtime
  # PULSE_RUNTIME_PATH places the Pulse native socket at
  # /run/pulse/runtime/native — the path moonlight clients already use.
  export PULSE_RUNTIME_PATH=/run/pulse/runtime
  export PULSE_SERVER=unix:/run/pulse/runtime/native

  pipewire &
  wireplumber &
  pipewire-pulse &
  pulse_pid=$!

  wait_for_server
  wait_for_sink
  pactl set-default-sink sendspin
  pactl set-default-source sendspin.monitor

  # Stay as PID 1's waited child: exit when pipewire-pulse exits.
  wait "${pulse_pid}"
}

if [ "${1:-serve}" = "serve" ]; then
  start_pipewire
fi

export HOME="${HOME:-/home/player}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/runtime/native}"

if [ "$1" = "record-null" ]; then
  wait_for_server
  exec parec \
    --device=sendspin.monitor \
    --format=s16le \
    --rate=48000 \
    --channels=2 \
    >/dev/null
fi

wait_for_server
exec "$@"
