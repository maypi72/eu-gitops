{{- define "listmonk.name" -}}
listmonk
{{- end -}}

{{- define "listmonk.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "listmonk.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
