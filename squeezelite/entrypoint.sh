#!/bin/sh
set -eu

export HOME="${HOME:-/home/squeezelite}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/runtime/native}"

i=0
while ! pactl info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 150 ]; then
    echo "timed out waiting for PulseAudio at ${PULSE_SERVER}" >&2
    exit 1
  fi
  sleep 0.2
done

case "${1:-daemon}" in
  pactl|parec)
    exec "$@"
    ;;
esac

if [ "${1:-}" = "daemon" ]; then
  shift
fi

for arg in "$@"; do
  case "$arg" in
    *'${SQUEEZELITE_SERVER}'*)
      if [ -z "${SQUEEZELITE_SERVER:-}" ]; then
        echo "SQUEEZELITE_SERVER is unset" >&2
        exit 1
      fi
      ;;
  esac
done

n=0
for arg in "$@"; do
  n=$((n + 1))
  eval "slot_${n}=\$(printf '%s' \"$arg\")"
done

if [ "$n" -eq 0 ]; then
  echo "squeezelite arguments are empty" >&2
  exit 1
fi

set --
i=1
while [ "$i" -le "$n" ]; do
  eval "set -- \"\$@\" \"\$slot_${i}\""
  i=$((i + 1))
done

# Default to the Pulse null sink when the caller did not name an output.
has_output=0
for arg in "$@"; do
  case "$arg" in
    -o) has_output=1 ;;
  esac
done
if [ "$has_output" -eq 0 ]; then
  set -- -o "${SQUEEZELITE_OUTPUT:-pulse}" "$@"
fi

echo "exec squeezelite $*" >&2
exec squeezelite "$@"
