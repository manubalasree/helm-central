{{/*
Chart name, truncated to fit Kubernetes' 63-char label limit.
*/}}
{{- define "ministack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, used as the base for resource names.
Combines the release name with the chart name unless the release name
already contains the chart name, or a fullnameOverride is set.
*/}}
{{- define "ministack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels applied to every resource.
*/}}
{{- define "ministack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "ministack.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels, used to link a Deployment to its Pods and a Service to its
Deployment. These must never change across chart versions, or upgrades break.
*/}}
{{- define "ministack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ministack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
