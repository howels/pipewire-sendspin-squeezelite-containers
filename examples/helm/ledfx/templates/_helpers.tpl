{{- define "ledfx.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{- define "ledfx.app" -}}
{{- required "names.app is required" .Values.names.app -}}
{{- end -}}

{{- define "ledfx.pulseClientConfig" -}}
{{- required "names.pulseClientConfig is required" .Values.names.pulseClientConfig -}}
{{- end -}}

{{- define "ledfx.dataClaim" -}}
{{- required "names.dataClaim is required" .Values.names.dataClaim -}}
{{- end -}}

{{- define "ledfx.sendspinClaim" -}}
{{- required "names.sendspinClaim is required" .Values.names.sendspinClaim -}}
{{- end -}}

{{- define "ledfx.image" -}}
{{- $img := index .root.Values.images .key -}}
{{- printf "%s:%s" (required (printf "images.%s.repository is required" .key) $img.repository) (required (printf "images.%s.tag is required" .key) ($img.tag | toString)) -}}
{{- end -}}
