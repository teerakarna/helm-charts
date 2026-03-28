{{/*
Expand the name of the chart.
*/}}
{{- define "kube-hunter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kube-hunter.fullname" -}}
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
Create chart name and version label value.
*/}}
{{- define "kube-hunter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kube-hunter.labels" -}}
helm.sh/chart: {{ include "kube-hunter.chart" . }}
{{ include "kube-hunter.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kube-hunter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-hunter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "kube-hunter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kube-hunter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
CLI args for kube-hunter.
Builds: kube-hunter [--pod | --cidr CIDR] [--active] --report FORMAT [--statistics]
*/}}
{{- define "kube-hunter.args" -}}
{{- if eq .Values.scope "pod" }}
- --pod
{{- else if eq .Values.scope "cidr" }}
- --cidr
- {{ .Values.cidr | quote }}
{{- end }}
{{- if .Values.active }}
- --active
{{- end }}
- --report
- {{ .Values.report | quote }}
{{- if .Values.statistics }}
- --statistics
{{- end }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
kube-hunter scans the network — it does not need the Kubernetes API token.
*/}}
{{- define "kube-hunter.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "kube-hunter.serviceAccountName" . }}
automountServiceAccountToken: false
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: {{ .Chart.Name }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    args:
      {{- include "kube-hunter.args" . | trim | nindent 6 }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
