{{/*
Expand the name of the chart.
*/}}
{{- define "aks-finops-toolkit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "aks-finops-toolkit.fullname" -}}
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
Create chart label.
*/}}
{{- define "aks-finops-toolkit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "aks-finops-toolkit.labels" -}}
helm.sh/chart: {{ include "aks-finops-toolkit.chart" . }}
{{ include "aks-finops-toolkit.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: aks-finops-toolkit
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "aks-finops-toolkit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aks-finops-toolkit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Grafana dashboard ConfigMap label — must match the sidecar label in values.yaml.
*/}}
{{- define "aks-finops-toolkit.dashboardLabel" -}}
grafana_dashboard: "1"
{{- end }}
