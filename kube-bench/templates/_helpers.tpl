{{/*
Expand the name of the chart.
*/}}
{{- define "kube-bench.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kube-bench.fullname" -}}
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
{{- define "kube-bench.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kube-bench.labels" -}}
helm.sh/chart: {{ include "kube-bench.chart" . }}
{{ include "kube-bench.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kube-bench.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-bench.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "kube-bench.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kube-bench.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PVC name — uses existingClaim if set, otherwise the release-scoped name.
*/}}
{{- define "kube-bench.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "kube-bench.fullname" . }}
{{- end }}
{{- end }}

{{/*
CLI args for kube-bench.
Builds: kube-bench run [--targets ...] [--benchmark ...] [--version ...]
        [--json|--junit|--asff] [--outputfile ...]
*/}}
{{- define "kube-bench.args" -}}
- run
{{- if .Values.targets }}
- --targets
- {{ .Values.targets | join "," | quote }}
{{- end }}
{{- if .Values.benchmark }}
- --benchmark
- {{ .Values.benchmark | quote }}
{{- end }}
{{- if .Values.kubernetesVersion }}
- --version
- {{ .Values.kubernetesVersion | quote }}
{{- end }}
{{- if eq .Values.outputFormat "json" }}
- --json
{{- else if eq .Values.outputFormat "junit" }}
- --junit
{{- else if eq .Values.outputFormat "asff" }}
- --asff
{{- end }}
{{- if .Values.persistence.enabled }}
- --outputfile
- {{ printf "%s/results.%s" .Values.persistence.mountPath .Values.outputFormat | quote }}
{{- end }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
kube-bench needs the ServiceAccount token to query the Kubernetes API,
so automountServiceAccountToken is set to true at the pod level.
*/}}
{{- define "kube-bench.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "kube-bench.serviceAccountName" . }}
automountServiceAccountToken: true
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
      {{- include "kube-bench.args" . | trim | nindent 6 }}
    volumeMounts:
      - name: results
        mountPath: {{ .Values.persistence.mountPath }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
volumes:
  - name: results
    {{- if .Values.persistence.enabled }}
    persistentVolumeClaim:
      claimName: {{ include "kube-bench.pvcName" . }}
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
