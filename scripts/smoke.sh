#!/usr/bin/env bash
# Start the pipewire image and confirm sendspin (as uid 1000) sees sendspin.monitor
# on the shared volume. Mirrors kubernetes-cluster/moonlight/scripts/smoke.sh.
set -euo pipefail

TAG="${TAG:-dev}"
PREFIX="${PREFIX:-localhost}"
VOL="pipewire-sendspin-smoke"
NAME="pipewire-sendspin-smoke"

cleanup() {
  podman rm -f "$NAME" >/dev/null 2>&1 || true
  podman volume rm "$VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

podman volume create "$VOL" >/dev/null
# Volume mount replaces the image's /run/pulse; seed a uid-1000 runtime dir.
podman run --rm -v "$VOL:/run/pulse" --user 0:0 alpine:3.22 \
  sh -c 'mkdir -p /run/pulse/runtime && chown -R 1000:1000 /run/pulse && chmod 700 /run/pulse/runtime'
podman run -d --name "$NAME" --user 1000:1000 -v "$VOL:/run/pulse" \
  "${PREFIX}/pipewire:${TAG}"

i=0
while ! podman exec "$NAME" pactl info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 50 ]; then
    echo "timed out waiting for pipewire Pulse socket" >&2
    podman logs "$NAME" >&2 || true
    exit 1
  fi
  sleep 0.2
done

info="$(podman run --rm --user 1000:1000 -v "$VOL:/run/pulse" \
  -e PULSE_SERVER=unix:/run/pulse/runtime/native \
  -e XDG_RUNTIME_DIR=/tmp \
  "${PREFIX}/sendspin:${TAG}" pactl info)"
printf '%s\n' "$info"
case "$info" in
  *"/run/pulse/runtime/native"*) ;;
  *)
    echo "sendspin image did not reach the shared Pulse socket" >&2
    exit 1
    ;;
esac
case "$info" in
  *"PipeWire"*) ;;
  *)
    echo "expected Server Name to mention PipeWire" >&2
    exit 1
    ;;
esac

sources="$(podman exec "$NAME" pactl list short sources)"
printf '%s\n' "$sources"
case "$sources" in
  *sendspin.monitor*) ;;
  *)
    echo "null-sink monitor sendspin.monitor is missing" >&2
    exit 1
    ;;
esac

if podman image exists "${PREFIX}/squeezelite:${TAG}"; then
  sq="$(podman run --rm --user 1000:1000 -v "$VOL:/run/pulse" \
    -e PULSE_SERVER=unix:/run/pulse/runtime/native \
    -e XDG_RUNTIME_DIR=/tmp \
    "${PREFIX}/squeezelite:${TAG}" pactl info)"
  case "$sq" in
    *"/run/pulse/runtime/native"*) ;;
    *)
      echo "squeezelite image did not reach the shared Pulse socket" >&2
      exit 1
      ;;
  esac
  echo "squeezelite shared socket ok"
fi

echo "shared PipeWire Pulse socket ok"
