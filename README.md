# pipewire-sendspin-squeezelite-containers

Three container images that share a PulseAudio-compatible Unix socket backed by PipeWire:

| Image | Role |
|-------|------|
| `ghcr.io/howels/pipewire` | PipeWire + `pipewire-pulse` with null sink `sendspin` |
| `ghcr.io/howels/sendspin` | [sendspin-cpp-cli](https://github.com/Sendspin/sendspin-cpp-cli) player (`-o pulse`) |
| `ghcr.io/howels/squeezelite` | [ralph-irving/squeezelite](https://github.com/ralph-irving/squeezelite) with Pulse output |

Built for `linux/amd64` and `linux/arm64`. Published to GHCR on every push to `main`.

## Why PipeWire

Clients still speak the Pulse protocol on `unix:/run/pulse/runtime/native`. PipeWire is the maintained graph, carries lower default buffering than classic PulseAudio, and Alpine 3.22 ships PipeWire 1.4.x (newer than Debian trixie's 1.4.2). PulseAudio upstream is effectively frozen at 17.0.

Clock and Pulse-compat buffering are tuned in:

- `pipewire/pipewire.conf.d/99-sendspin-clock.conf` — `default.clock.quantum = 256` (~5.3 ms at 48 kHz)
- `pipewire/pipewire-pulse.conf.d/99-sendspin.conf` — null sink `sendspin`, `client.access = allowed`

## Version pins

`versions.env` holds the upstream pins. Renovate opens weekly PRs when Alpine, Debian, sendspin-cpp-cli, or squeezelite move. PipeWire tracks the Alpine base.

| Pin | Tracks |
|-----|--------|
| `ALPINE_VERSION` | Alpine base (PipeWire + Squeezelite) |
| `DEBIAN_VERSION` | Debian slim base (sendspin-cli build/runtime) |
| `SENDSPIN_CLI_REF` | `Sendspin/sendspin-cpp-cli` release tag |
| `SQUEEZELITE_REF` | `ralph-irving/squeezelite` commit on `master` |

## Sendspin args

The sendspin entrypoint accepts the former Python client args and maps them onto `sendspin-cli`:

| Python / chart arg | sendspin-cli |
|--------------------|--------------|
| `daemon` | dropped (process stays foreground) |
| `--name` | `--name` |
| `--url ws://host:8927/sendspin` | `--server` with the same value |
| `--audio-format` | `--audio-format` |
| `--settings-dir /data` | `--state-dir /data` |
| (implicit default sink) | `--output pulse` |

`${SENDSPIN_SERVER}` and `$(hostname)` in Kubernetes args are expanded by the entrypoint. `--allow-unpaired` is added unless `SENDSPIN_REQUIRE_PAIRING=1`.

Native `sendspin-cli` flags pass through unchanged.

Example (matches the moonlight chart shape):

```text
daemon
--name
moonlight-sendspin
--url
ws://${SENDSPIN_SERVER}:8927/sendspin
--audio-format
flac:22050:16:2
--settings-dir
/data
```

## Shared Pulse socket

All three images run as uid/gid `1000` and expect:

```text
PULSE_SERVER=unix:/run/pulse/runtime/native
```

Mount a shared volume at `/run/pulse`. The pipewire image creates `/run/pulse/runtime` mode `0700`, starts PipeWire + WirePlumber + `pipewire-pulse`, and listens on `native` with unrestricted Pulse client access. Clients set `XDG_RUNTIME_DIR=/tmp` and ship `autospawn = no` in `/etc/pulse/client.conf`. Sink `sendspin` and source `sendspin.monitor` remain the defaults.

## Local build

```bash
make build TAG=dev PLATFORM=linux/amd64
```

Push (needs `podman login ghcr.io`):

```bash
make push TAG=dev PLATFORM=linux/amd64
```

## CI

- `.github/workflows/build-publish.yml` — multi-arch build; push to GHCR on `main` and `v*` tags
- `.github/workflows/renovate.yml` — scheduled Renovate run

Renovate needs a repository secret `RENOVATE_TOKEN` (PAT with `repo` and `workflow`). Alternatively install the [Renovate GitHub App](https://github.com/apps/renovate) on this repository and disable the workflow.

## Image layout

- `pipewire/` — Alpine; PipeWire + `pipewire-pulse` + WirePlumber (`pactl` from `pulseaudio-utils`)
- `sendspin/` — multi-stage Debian; builds sendspin-cli with Pulse + ALSA only (no PortAudio, PipeWire native, mDNS, or TUI)
- `squeezelite/` — multi-stage Alpine; builds squeezelite with `-DPULSEAUDIO -DLINKALL`
