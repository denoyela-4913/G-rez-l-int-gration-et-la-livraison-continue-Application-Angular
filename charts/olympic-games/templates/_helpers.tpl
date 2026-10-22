{{/* Étiquettes communes à toutes les ressources du chart. */}}
{{- define "olympic-games.labels" -}}
app.kubernetes.io/name: olympic-games
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ (split ":" .Values.app.image)._1 | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
