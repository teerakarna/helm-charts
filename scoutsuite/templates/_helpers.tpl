{{/*
Expand the name of the chart.
*/}}
{{- define "scoutsuite.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "scoutsuite.fullname" -}}
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
{{- define "scoutsuite.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "scoutsuite.labels" -}}
helm.sh/chart: {{ include "scoutsuite.chart" . }}
{{ include "scoutsuite.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "scoutsuite.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scoutsuite.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "scoutsuite.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "scoutsuite.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PVC name — uses existingClaim if set, otherwise the release-scoped name.
*/}}
{{- define "scoutsuite.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "scoutsuite.fullname" . }}
{{- end }}
{{- end }}

{{/*
Auth-related environment variables injected from Secrets.
Only the block matching .Values.provider is rendered.
*/}}
{{- define "scoutsuite.authEnv" -}}
{{- if eq .Values.provider "aws" }}
{{- if and (eq .Values.auth.aws.mode "accessKeys") .Values.auth.aws.existingSecret }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.aws.existingSecret }}
      key: {{ .Values.auth.aws.accessKeyIdKey }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.aws.existingSecret }}
      key: {{ .Values.auth.aws.secretAccessKeyKey }}
{{- if .Values.auth.aws.sessionTokenKey }}
- name: AWS_SESSION_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.aws.existingSecret }}
      key: {{ .Values.auth.aws.sessionTokenKey }}
{{- end }}
{{- end }}
{{- end }}
{{- if eq .Values.provider "azure" }}
{{- if and (eq .Values.auth.azure.mode "servicePrincipal") .Values.auth.azure.existingSecret }}
- name: AZURE_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.azure.existingSecret }}
      key: {{ .Values.auth.azure.clientIdKey }}
- name: AZURE_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.azure.existingSecret }}
      key: {{ .Values.auth.azure.clientSecretKey }}
- name: AZURE_TENANT_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.azure.existingSecret }}
      key: {{ .Values.auth.azure.tenantIdKey }}
{{- end }}
{{- end }}
{{- if eq .Values.provider "aliyun" }}
{{- if .Values.auth.aliyun.existingSecret }}
- name: ALIYUN_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.aliyun.existingSecret }}
      key: {{ .Values.auth.aliyun.accessKeyIdKey }}
- name: ALIYUN_ACCESS_KEY_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.aliyun.existingSecret }}
      key: {{ .Values.auth.aliyun.accessKeySecretKey }}
{{- end }}
{{- end }}
{{- if eq .Values.provider "do" }}
{{- if .Values.auth.do.existingSecret }}
- name: DO_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.do.existingSecret }}
      key: {{ .Values.auth.do.tokenKey }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Auth-related volumes (GCP service account key file).
*/}}
{{- define "scoutsuite.authVolumes" -}}
{{- if and (eq .Values.provider "gcp") (eq .Values.auth.gcp.mode "serviceAccount") .Values.auth.gcp.existingSecret }}
- name: gcp-key
  secret:
    secretName: {{ .Values.auth.gcp.existingSecret }}
    items:
      - key: {{ .Values.auth.gcp.keyFileKey }}
        path: key.json
{{- end }}
{{- end }}

{{/*
Auth-related volume mounts (GCP service account key file).
*/}}
{{- define "scoutsuite.authVolumeMounts" -}}
{{- if and (eq .Values.provider "gcp") (eq .Values.auth.gcp.mode "serviceAccount") .Values.auth.gcp.existingSecret }}
- name: gcp-key
  mountPath: {{ dir .Values.auth.gcp.mountPath }}
  readOnly: true
{{- end }}
{{- end }}

{{/*
CLI args for the scout command.
Builds: scout <provider> [auth-args] [scope-args] [output-args]
--no-browser is always set (never applicable in Kubernetes).
*/}}
{{- define "scoutsuite.args" -}}
- {{ .Values.provider }}
{{- /* GCP auth args */}}
{{- if eq .Values.provider "gcp" }}
{{- if eq .Values.auth.gcp.mode "serviceAccount" }}
- --service-account
- {{ .Values.auth.gcp.mountPath | quote }}
{{- end }}
{{- if .Values.auth.gcp.projectId }}
- --project-id
- {{ .Values.auth.gcp.projectId | quote }}
{{- end }}
{{- if .Values.auth.gcp.organizationId }}
- --organization-id
- {{ .Values.auth.gcp.organizationId | quote }}
{{- end }}
{{- if .Values.auth.gcp.folderId }}
- --folder-id
- {{ .Values.auth.gcp.folderId | quote }}
{{- end }}
{{- if .Values.auth.gcp.allProjects }}
- --all-projects
{{- end }}
{{- end }}
{{- /* Azure auth args */}}
{{- if eq .Values.provider "azure" }}
{{- if eq .Values.auth.azure.mode "workloadIdentity" }}
- --msi
{{- else if eq .Values.auth.azure.mode "servicePrincipal" }}
- --service-principal
- --client-id
- $(AZURE_CLIENT_ID)
- --client-secret
- $(AZURE_CLIENT_SECRET)
- --tenant-id
- $(AZURE_TENANT_ID)
{{- end }}
{{- if .Values.auth.azure.subscriptionIds }}
- --subscription-ids
{{- range .Values.auth.azure.subscriptionIds }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.auth.azure.allSubscriptions }}
- --all-subscriptions
{{- end }}
{{- end }}
{{- /* AWS scope args */}}
{{- if eq .Values.provider "aws" }}
{{- if .Values.scout.regions }}
- --regions
{{- range .Values.scout.regions }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.scout.excludedRegions }}
- --exclude-regions
{{- range .Values.scout.excludedRegions }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.scout.ipRanges }}
- --ip-ranges
{{- range .Values.scout.ipRanges }}
- {{ . | quote }}
{{- end }}
- --ip-ranges-name-key
- {{ .Values.scout.ipRangesNameKey | quote }}
{{- end }}
{{- end }}
{{- /* Common scope args */}}
{{- if .Values.scout.services }}
- --services
{{- range .Values.scout.services }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.scout.skip }}
- --skip
{{- range .Values.scout.skip }}
- {{ . | quote }}
{{- end }}
{{- end }}
- --max-workers
- {{ .Values.scout.maxWorkers | quote }}
{{- if .Values.scout.maxRate }}
- --max-rate
- {{ .Values.scout.maxRate | quote }}
{{- end }}
- --ruleset
- {{ .Values.scout.ruleset | quote }}
- --result-format
- {{ .Values.scout.resultFormat | quote }}
{{- if .Values.scout.timestamp }}
- --timestamp
{{- end }}
{{- if .Values.scout.force }}
- --force
{{- end }}
{{- /* Output args */}}
- --no-browser
- --report-dir
- {{ .Values.output.reportDir | quote }}
{{- if .Values.output.reportName }}
- --report-name
- {{ .Values.output.reportName | quote }}
{{- end }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "scoutsuite.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "scoutsuite.serviceAccountName" . }}
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
      {{- include "scoutsuite.args" . | trim | nindent 6 }}
    {{- $authEnv := include "scoutsuite.authEnv" . }}
    {{- if $authEnv }}
    env:
      {{- $authEnv | nindent 6 }}
    {{- end }}
    volumeMounts:
      - name: reports
        mountPath: {{ .Values.persistence.mountPath }}
      {{- include "scoutsuite.authVolumeMounts" . | nindent 6 }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
volumes:
  - name: reports
    {{- if .Values.persistence.enabled }}
    persistentVolumeClaim:
      claimName: {{ include "scoutsuite.pvcName" . }}
    {{- else }}
    emptyDir: {}
    {{- end }}
  {{- include "scoutsuite.authVolumes" . | nindent 2 }}
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
