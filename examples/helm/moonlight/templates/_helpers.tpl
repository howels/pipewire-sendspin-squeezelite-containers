{{- define "moonlight.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{- define "moonlight.app" -}}
{{- required "names.app is required" .Values.names.app -}}
{{- end -}}

{{- define "moonlight.pulseClientConfig" -}}
{{- required "names.pulseClientConfig is required" .Values.names.pulseClientConfig -}}
{{- end -}}

{{- define "moonlight.dataClaim" -}}
{{- required "names.dataClaim is required" .Values.names.dataClaim -}}
{{- end -}}

{{- define "moonlight.sendspinClaim" -}}
{{- required "names.sendspinClaim is required" .Values.names.sendspinClaim -}}
{{- end -}}

{{- define "moonlight.image" -}}
{{- $img := index .root.Values.images .key -}}
{{- printf "%s:%s" (required (printf "images.%s.repository is required" .key) $img.repository) (required (printf "images.%s.tag is required" .key) ($img.tag | toString)) -}}
{{- end -}}
