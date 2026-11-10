{{- define "gcp.required" -}}
{{- required (printf "%s is required; it comes from the hub cluster Secret annotations" .name) .value -}}
{{- end -}}
