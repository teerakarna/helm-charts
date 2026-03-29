{{/*
Expand the name of the chart.
*/}}
{{- define "zaproxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zaproxy.fullname" -}}
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
{{- define "zaproxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zaproxy.labels" -}}
helm.sh/chart: {{ include "zaproxy.chart" . }}
{{ include "zaproxy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zaproxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zaproxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "zaproxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zaproxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PVC name — uses existingClaim if set, otherwise the release-scoped name.
*/}}
{{- define "zaproxy.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "zaproxy.fullname" . }}
{{- end }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "zaproxy.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "zaproxy.serviceAccountName" . }}
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
      - -cmd
      - -autorun
      - /zap/wrk/automation.yaml
    env:
      - name: TARGET_URL
        value: {{ .Values.target.url | quote }}
    volumeMounts:
      - name: plan
        mountPath: /zap/wrk/automation.yaml
        subPath: automation.yaml
        readOnly: true
      - name: reports
        mountPath: {{ .Values.persistence.mountPath }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
volumes:
  - name: plan
    configMap:
      name: {{ include "zaproxy.fullname" . }}
  - name: reports
    {{- if .Values.persistence.enabled }}
    persistentVolumeClaim:
      claimName: {{ include "zaproxy.pvcName" . }}
    {{- else }}
    emptyDir: {}
    {{- end }}
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
