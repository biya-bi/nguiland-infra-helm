{{/*
Expand the name of the chart.
*/}}
{{- define "chart-repository.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "chart-repository.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart-repository.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chart-repository.labels" -}}
helm.sh/chart: {{ include "chart-repository.chart" . }}
{{ include "chart-repository.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "chart-repository.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart-repository.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "chart-repository.serviceAccountName" -}}
{{- $sa := .Values.serviceAccount | default dict -}}
{{- if hasKey $sa "create" | ternary $sa.create true -}}
{{- default (include "chart-repository.fullname" .) $sa.name -}}
{{- else -}}
{{- default "default" $sa.name -}}
{{- end -}}
{{- end }}

{{/*
Environment variables shared by containers
*/}}
{{- define "chart-repository.env" -}}
{{- range $name, $value := .envMap | default dict }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- with .env }}
{{- toYaml . }}
{{- end }}
{{- with .envSecrets }}
{{- toYaml . }}
{{- end }}
{{- end }}
