{{- define "imageName" -}}
    {{ $name := printf "%s:%s" .values.app.name .values.app.tag }}
    {{- $name }}
{{- end }}
