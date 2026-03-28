{{/*
Expand the name of the chart.
*/}}
{{- define "bombardier.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bombardier.fullname" -}}
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
{{- define "bombardier.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bombardier.labels" -}}
helm.sh/chart: {{ include "bombardier.chart" . }}
{{ include "bombardier.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bombardier.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bombardier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "bombardier.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "bombardier.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
CLI args for bombardier.
Builds: bombardier [options] <url>
The target URL is always the last argument.
*/}}
{{- define "bombardier.args" -}}
- --connections
- {{ .Values.bombardier.connections | quote }}
{{- if .Values.bombardier.requests }}
- --requests
- {{ .Values.bombardier.requests | quote }}
{{- else if .Values.bombardier.duration }}
- --duration
- {{ .Values.bombardier.duration | quote }}
{{- end }}
{{- if .Values.bombardier.rate }}
- --rate
- {{ .Values.bombardier.rate | quote }}
{{- end }}
- --method
- {{ .Values.bombardier.method | quote }}
{{- range $k, $v := .Values.bombardier.headers }}
- --header
- {{ printf "%s:%s" $k $v | quote }}
{{- end }}
{{- if .Values.bombardier.body }}
- --body
- {{ .Values.bombardier.body | quote }}
{{- end }}
- --timeout
- {{ .Values.bombardier.timeout | quote }}
{{- if .Values.bombardier.insecure }}
- --insecure
{{- end }}
{{- if not .Values.bombardier.http2 }}
- --http1
{{- end }}
{{- if .Values.bombardier.latencies }}
- --latencies
{{- end }}
- --format
- {{ .Values.bombardier.format | quote }}
- {{ .Values.target.url | quote }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "bombardier.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "bombardier.serviceAccountName" . }}
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
      {{- include "bombardier.args" . | trim | nindent 6 }}
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
