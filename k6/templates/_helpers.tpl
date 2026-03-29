{{/*
Expand the name of the chart.
*/}}
{{- define "k6.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "k6.fullname" -}}
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
{{- define "k6.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k6.labels" -}}
helm.sh/chart: {{ include "k6.chart" . }}
{{ include "k6.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k6.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k6.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "k6.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k6.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
CLI args for k6.
Builds: k6 run [--env KEY=VALUE ...] /scripts/test.js
*/}}
{{- define "k6.args" -}}
- run
{{- range $k, $v := .Values.env }}
- --env
- {{ printf "%s=%s" $k $v | quote }}
{{- end }}
- /scripts/test.js
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "k6.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "k6.serviceAccountName" . }}
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
      {{- include "k6.args" . | trim | nindent 6 }}
    volumeMounts:
      - name: scripts
        mountPath: /scripts
        readOnly: true
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
volumes:
  - name: scripts
    configMap:
      name: {{ include "k6.fullname" . }}
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
