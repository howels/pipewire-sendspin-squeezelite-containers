#!/bin/sh
# Wait for the shared PulseAudio socket, expand Kubernetes-style placeholders,
# map the former Python sendspin flags onto sendspin-cli, then exec.
set -eu

export HOME="${HOME:-/home/sendspin}"
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

case "${1:-}" in
  pactl|parec)
    exec "$@"
    ;;
esac

# Drop the Python client's leading "daemon" token; sendspin-cli is foreground.
if [ "${1:-}" = "daemon" ]; then
  shift
fi

for arg in "$@"; do
  case "$arg" in
    *'${SENDSPIN_SERVER}'*)
      if [ -z "${SENDSPIN_SERVER:-}" ]; then
        echo "SENDSPIN_SERVER is unset" >&2
        exit 1
      fi
      ;;
  esac
done

# Expand $(hostname) and ${SENDSPIN_SERVER} the way the Python entrypoint did.
# Kubernetes container args are not shell-expanded.
n=0
for arg in "$@"; do
  n=$((n + 1))
  eval "slot_${n}=\$(printf '%s' \"$arg\")"
done

set --
i=1
while [ "$i" -le "$n" ]; do
  eval "set -- \"\$@\" \"\$slot_${i}\""
  i=$((i + 1))
done

# Translate Python sendspin flags that differ on sendspin-cli.
has_output=0
mapped=
set -- "$@"
# Rebuild into a fresh argv with mapped flags.
out_n=0
prev=
for arg in "$@"; do
  if [ "$prev" = "--url" ]; then
    out_n=$((out_n + 1))
    eval "out_${out_n}=--server"
    out_n=$((out_n + 1))
    eval "out_${out_n}=\$arg"
    prev=
    continue
  fi
  if [ "$prev" = "--settings-dir" ]; then
    out_n=$((out_n + 1))
    eval "out_${out_n}=--state-dir"
    out_n=$((out_n + 1))
    eval "out_${out_n}=\$arg"
    prev=
    continue
  fi
  case "$arg" in
    --url|--settings-dir)
      prev=$arg
      continue
      ;;
    -o|--output)
      has_output=1
      ;;
    --output=*)
      has_output=1
      ;;
  esac
  out_n=$((out_n + 1))
  eval "out_${out_n}=\$arg"
  prev=
done
if [ -n "$prev" ]; then
  echo "flag $prev requires a value" >&2
  exit 1
fi

set --
i=1
while [ "$i" -le "$out_n" ]; do
  eval "set -- \"\$@\" \"\$out_${i}\""
  i=$((i + 1))
done

if [ "$has_output" -eq 0 ]; then
  set -- --output "${SENDSPIN_OUTPUT:-pulse}" "$@"
fi

# Python sendspin did not enforce Noise pairing the same way. Default to
# allowing unpaired servers so a drop-in chart args list keeps working.
# Set SENDSPIN_REQUIRE_PAIRING=1 to omit --allow-unpaired.
case " $* " in
  *" --allow-unpaired "*|*" --allow-unpaired="*) ;;
  *)
    if [ "${SENDSPIN_REQUIRE_PAIRING:-0}" != "1" ]; then
      set -- --allow-unpaired "$@"
    fi
    ;;
esac

if [ "$#" -eq 0 ]; then
  echo "sendspin-cli arguments are empty" >&2
  exit 1
fi

echo "exec sendspin-cli $*" >&2
exec sendspin-cli "$@"
