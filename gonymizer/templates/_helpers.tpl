{{/*
Expand the name of the chart.
*/}}
{{- define "gonymizer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "gonymizer.fullname" -}}
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
{{- define "gonymizer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gonymizer.labels" -}}
helm.sh/chart: {{ include "gonymizer.chart" . }}
{{ include "gonymizer.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gonymizer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gonymizer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "gonymizer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gonymizer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PVC name.
*/}}
{{- define "gonymizer.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "gonymizer.fullname" . }}
{{- end }}
{{- end }}

{{/*
ConfigMap name for the map file.
*/}}
{{- define "gonymizer.mapFileConfigMapName" -}}
{{- if .Values.mapFile.existingConfigMap }}
{{- .Values.mapFile.existingConfigMap }}
{{- else }}
{{- printf "%s-mapfile" (include "gonymizer.fullname" .) }}
{{- end }}
{{- end }}

{{/*
ConfigMap name for the config file.
*/}}
{{- define "gonymizer.configFileConfigMapName" -}}
{{- if .Values.configFile.existingConfigMap }}
{{- .Values.configFile.existingConfigMap }}
{{- else }}
{{- printf "%s-config" (include "gonymizer.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Database credential environment variables injected from Secrets.
Gonymizer uses Viper with GON_ prefix — passwords are picked up automatically
without appearing in the CLI args.

Viper key bindings:
  map.password   → GON_MAP_PASSWORD
  dump.password  → GON_DUMP_PASSWORD
  load.password  → GON_LOAD_PASSWORD
*/}}
{{- define "gonymizer.credentialsEnv" -}}
{{- if or (eq .Values.command "map") (eq .Values.command "dump") }}
{{- if .Values.source.existingSecret }}
- name: {{ upper (printf "GON_%s_PASSWORD" .Values.command) }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.source.existingSecret }}
      key: {{ .Values.source.passwordKey }}
{{- end }}
{{- end }}
{{- if eq .Values.command "load" }}
{{- if .Values.target.existingSecret }}
- name: GON_LOAD_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.target.existingSecret }}
      key: {{ .Values.target.passwordKey }}
{{- end }}
{{- end }}
{{- if and (eq .Values.command "upload") (not .Values.s3.useIRSA) .Values.s3.existingSecret }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.existingSecret }}
      key: {{ .Values.s3.accessKeyIdKey }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.existingSecret }}
      key: {{ .Values.s3.secretAccessKeyKey }}
{{- end }}
{{- end }}

{{/*
Volumes for config/map files and persistent data storage.
*/}}
{{- define "gonymizer.volumes" -}}
- name: data
  {{- if .Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ include "gonymizer.pvcName" . }}
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- if .Values.mapFile.enabled }}
- name: mapfile
  configMap:
    name: {{ include "gonymizer.mapFileConfigMapName" . }}
    items:
      - key: {{ .Values.mapFile.contentKey }}
        path: {{ base .Values.mapFile.mountPath }}
{{- end }}
{{- if .Values.configFile.enabled }}
- name: configfile
  configMap:
    name: {{ include "gonymizer.configFileConfigMapName" . }}
    items:
      - key: {{ .Values.configFile.contentKey }}
        path: {{ base .Values.configFile.mountPath }}
{{- end }}
{{- end }}

{{/*
Volume mounts for config/map files and persistent data storage.
*/}}
{{- define "gonymizer.volumeMounts" -}}
- name: data
  mountPath: {{ .Values.persistence.mountPath }}
{{- if .Values.mapFile.enabled }}
- name: mapfile
  mountPath: {{ .Values.mapFile.mountPath }}
  subPath: {{ base .Values.mapFile.mountPath }}
  readOnly: true
{{- end }}
{{- if .Values.configFile.enabled }}
- name: configfile
  mountPath: {{ .Values.configFile.mountPath }}
  subPath: {{ base .Values.configFile.mountPath }}
  readOnly: true
{{- end }}
{{- end }}

{{/*
CLI args for the gonymizer command.
Passwords are never included — they are injected via GON_*_PASSWORD env vars.
*/}}
{{- define "gonymizer.args" -}}
{{- /* Global flags */}}
{{- if .Values.configFile.enabled }}
- --config
- {{ .Values.configFile.mountPath | quote }}
{{- end }}
- --log-level
- {{ .Values.logging.level | quote }}
- --log-format
- {{ .Values.logging.format | quote }}
{{- if .Values.logging.file }}
- --log-file
- {{ .Values.logging.file | quote }}
{{- end }}
{{- /* Subcommand */}}
- {{ .Values.command }}
{{- /* map / dump: source DB connection */}}
{{- if or (eq .Values.command "map") (eq .Values.command "dump") }}
{{- if .Values.source.host }}
- --host
- {{ .Values.source.host | quote }}
{{- end }}
- --port
- {{ .Values.source.port | quote }}
{{- if .Values.source.database }}
- --database
- {{ .Values.source.database | quote }}
{{- end }}
{{- if .Values.source.username }}
- --username
- {{ .Values.source.username | quote }}
{{- end }}
{{- if .Values.source.disableSSL }}
- --disable-ssl
{{- end }}
{{- end }}
{{- /* map: map file output + schema options */}}
{{- if eq .Values.command "map" }}
{{- if .Values.mapFile.enabled }}
- --map-file
- {{ .Values.mapFile.mountPath | quote }}
{{- end }}
{{- range .Values.dump.schema }}
- --schema
- {{ . | quote }}
{{- end }}
{{- if .Values.dump.schemaPrefix }}
- --schema-prefix
- {{ .Values.dump.schemaPrefix | quote }}
{{- end }}
{{- range .Values.dump.excludeTable }}
- --exclude-table
- {{ . | quote }}
{{- end }}
{{- range .Values.dump.excludeTableData }}
- --exclude-table-data
- {{ . | quote }}
{{- end }}
{{- end }}
{{- /* dump: all dump-specific flags */}}
{{- if eq .Values.command "dump" }}
- --dump-file
- {{ .Values.files.dumpFile | quote }}
{{- if .Values.mapFile.enabled }}
- --map-file
- {{ .Values.mapFile.mountPath | quote }}
{{- end }}
{{- range .Values.dump.schema }}
- --schema
- {{ . | quote }}
{{- end }}
{{- if .Values.dump.schemaPrefix }}
- --schema-prefix
- {{ .Values.dump.schemaPrefix | quote }}
{{- end }}
{{- range .Values.dump.excludeTable }}
- --exclude-table
- {{ . | quote }}
{{- end }}
{{- range .Values.dump.excludeTableData }}
- --exclude-table-data
- {{ . | quote }}
{{- end }}
{{- range .Values.dump.excludeSchema }}
- --exclude-schema
- {{ . | quote }}
{{- end }}
{{- if .Values.files.rowCountFile }}
- --row-count-file
- {{ .Values.files.rowCountFile | quote }}
{{- end }}
{{- if .Values.dump.oids }}
- --oids
{{- end }}
{{- end }}
{{- /* process: process-specific flags */}}
{{- if eq .Values.command "process" }}
- --dump-file
- {{ .Values.files.dumpFile | quote }}
- --processed-file
- {{ .Values.files.processedFile | quote }}
{{- if .Values.mapFile.enabled }}
- --map-file
- {{ .Values.mapFile.mountPath | quote }}
{{- end }}
{{- if .Values.files.preProcessFile }}
- --pre-process-file
- {{ .Values.files.preProcessFile | quote }}
{{- end }}
{{- if .Values.files.postProcessFile }}
- --post-process-file
- {{ .Values.files.postProcessFile | quote }}
{{- end }}
{{- if .Values.process.generateSeed }}
- --generate-seed
{{- end }}
{{- if .Values.process.inclusive }}
- --inclusive
{{- end }}
{{- end }}
{{- /* load: target DB connection */}}
{{- if eq .Values.command "load" }}
{{- if .Values.target.host }}
- --host
- {{ .Values.target.host | quote }}
{{- end }}
- --port
- {{ .Values.target.port | quote }}
{{- if .Values.target.database }}
- --database
- {{ .Values.target.database | quote }}
{{- end }}
{{- if .Values.target.username }}
- --username
- {{ .Values.target.username | quote }}
{{- end }}
{{- if .Values.target.disableSSL }}
- --disable-ssl
{{- end }}
- --load-file
- {{ .Values.files.processedFile | quote }}
{{- if .Values.load.skipProcedures }}
- --skip-procedures
{{- end }}
{{- end }}
{{- /* upload: S3 upload flags */}}
{{- if eq .Values.command "upload" }}
{{- if .Values.upload.localFile }}
- --local-file
- {{ .Values.upload.localFile | quote }}
{{- end }}
{{- if .Values.upload.s3File }}
- --s3-file
- {{ .Values.upload.s3File | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Shared pod spec used by both CronJob and Job templates.
*/}}
{{- define "gonymizer.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "gonymizer.serviceAccountName" . }}
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
      {{- include "gonymizer.args" . | trim | nindent 6 }}
    {{- $credEnv := include "gonymizer.credentialsEnv" . }}
    {{- if $credEnv }}
    env:
      {{- $credEnv | nindent 6 }}
    {{- end }}
    volumeMounts:
      {{- include "gonymizer.volumeMounts" . | nindent 6 }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
volumes:
  {{- include "gonymizer.volumes" . | nindent 2 }}
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
