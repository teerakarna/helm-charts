{{/*
Expand the name of the chart.
*/}}
{{- define "trivy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "trivy.fullname" -}}
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
{{- define "trivy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "trivy.labels" -}}
helm.sh/chart: {{ include "trivy.chart" . }}
{{ include "trivy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "trivy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trivy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "trivy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trivy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PVC name — uses existingClaim if set, otherwise the release-scoped name.
*/}}
{{- define "trivy.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "trivy.fullname" . }}
{{- end }}
{{- end }}

{{/*
CLI args for trivy.
Builds: trivy <scanType> [options] <target>
*/}}
{{- define "trivy.args" -}}
- {{ .Values.scanType }}
- --severity
- {{ .Values.severity | quote }}
- --format
- {{ .Values.format | quote }}
{{- if or (eq .Values.scanType "image") (eq .Values.scanType "fs") (eq .Values.scanType "repo") }}
- --vuln-type
- {{ .Values.vulnType | quote }}
- --scanners
- {{ .Values.scanners | quote }}
{{- end }}
{{- if .Values.ignoreUnfixed }}
- --ignore-unfixed
{{- end }}
- --exit-code
- {{ .Values.exitCode | quote }}
{{- if .Values.skipUpdate }}
- --skip-db-update
{{- end }}
{{- if .Values.persistence.enabled }}
- --output
- {{ printf "%s/report.%s" .Values.persistence.mountPath .Values.format | quote }}
{{- end }}
- {{ .Values.target | quote }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "trivy.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "trivy.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.rbac.create }}
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
      {{- include "trivy.args" . | trim | nindent 6 }}
    {{- if .Values.persistence.enabled }}
    volumeMounts:
      - name: reports
        mountPath: {{ .Values.persistence.mountPath }}
    {{- end }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
{{- if .Values.persistence.enabled }}
volumes:
  - name: reports
    {{- if .Values.persistence.existingClaim }}
    persistentVolumeClaim:
      claimName: {{ include "trivy.pvcName" . }}
    {{- else if .Values.persistence.enabled }}
    persistentVolumeClaim:
      claimName: {{ include "trivy.pvcName" . }}
    {{- else }}
    emptyDir: {}
    {{- end }}
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
