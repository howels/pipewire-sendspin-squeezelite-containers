# Examples

How these images wire into MoonLight and LedFx. Production sources:

| Kind | MoonLight | LedFx |
|------|-----------|-------|
| Lab / Podman | `kubernetes-cluster/moonlight/moonlight-podman.yaml` | `kubernetes-cluster/ledfx/ledfx-study.yaml` |
| Cluster chart | `argo-charts-values/charts/local/moonlight` | `argo-charts-values/charts/local/ledfx` |

The examples here replace `registry.experimental.ninja/pulseaudio:dev` with `ghcr.io/howels/pipewire` and drop the `default.pa` mount. Null sink `sendspin` and the Pulse socket path are baked into the pipewire image. `client.conf` remains for app containers.

## Shared socket contract

All sidecars and the app share an `emptyDir` at `/run/pulse`:

```text
PULSE_SERVER=unix:/run/pulse/runtime/native
```

uid/gid `1000`. Sink `sendspin`, source `sendspin.monitor`.

## Podman

Edit `SENDSPIN_SERVER` (and host bind paths under `volume.podman.io/device`) then:

```bash
# MoonLight (pipewire + sendspin + squeezelite + moonlight)
podman kube play examples/podman/moonlight-pod.yaml

# LedFx (pipewire + sendspin + ledfx) — separate Pod
podman kube play examples/podman/ledfx-pod.yaml
```

Tear down:

```bash
podman kube down examples/podman/moonlight-pod.yaml
podman kube down examples/podman/ledfx-pod.yaml
```

For local builds instead of GHCR:

```bash
make build TAG=dev PLATFORM=linux/amd64
# then retag or edit the YAML image fields to localhost/pipewire:dev etc.
```

## Helm (Kubernetes illustration)

These charts show the same multi-container layout as the Argo charts, without Multus NAD or HTTPRoute. Use them to try the GHCR images, or as a reference when switching the production charts from `images.pulseaudio` to `images.pipewire`.

```bash
helm template moonlight examples/helm/moonlight --namespace moonlight
helm upgrade --install moonlight examples/helm/moonlight \
  --namespace moonlight --create-namespace \
  --set sendspin.server=192.168.0.190

helm template ledfx examples/helm/ledfx --namespace ledfx
helm upgrade --install ledfx examples/helm/ledfx \
  --namespace ledfx --create-namespace \
  --set sendspin.server=192.168.0.190
```

### Mapping to production values

Production overlays still name the key `images.pulseaudio`. When adopting these images, change that key (and the container name) to `pipewire`, set:

```yaml
images:
  pipewire:
    repository: ghcr.io/howels/pipewire
    tag: latest   # or a digest / sha- tag from CI
  sendspin:
    repository: ghcr.io/howels/sendspin
    tag: latest
  squeezelite:    # moonlight only
    repository: ghcr.io/howels/squeezelite
    tag: latest
```

and remove the `default.pa` volumeMount from the audio-server container. Keep the `client.conf` mount on MoonLight / LedFx.
