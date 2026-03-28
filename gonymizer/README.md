# gonymizer

PostgreSQL data anonymization tool ([Gonymizer](https://github.com/smithoss/gonymizer) by SmithRx). Runs as a Kubernetes CronJob or one-off Job to dump, anonymize, and optionally reload a PostgreSQL database — replacing PII/PHI with realistic fake data for use in QA and testing environments.

## How it works

Gonymizer operates as a pipeline of independent steps:

```
map     → generate a column anonymization map file from the source schema
dump    → dump PII/PHI data from the source database
process → anonymize the dump file using the map
load    → load the anonymized dump into the target database
upload  → upload a file to S3
```

Each step is a separate Job or CronJob. Run them in sequence to build a full pipeline. Running one step at a time means each is independently debuggable, re-runnable, and schedulable.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install gon-dump teerakarna/gonymizer \
  --set command=dump \
  --set source.host=prod-db.example.com \
  --set source.database=myapp \
  --set source.username=readonly \
  --set source.existingSecret=prod-db-credentials
```

## Full anonymization pipeline

### 1. Dump PII from source database

```bash
kubectl create secret generic prod-db-credentials \
  --from-literal=password=YOUR_PASSWORD

helm install gon-dump teerakarna/gonymizer \
  --set command=dump \
  --set workloadType=job \
  --set source.host=prod-db.example.com \
  --set source.database=myapp \
  --set source.username=readonly \
  --set source.existingSecret=prod-db-credentials \
  --set mapFile.enabled=true \
  --set mapFile.existingConfigMap=my-mapfile \
  --set "dump.schema={public,app}"
```

### 2. Anonymize the dump

```bash
helm install gon-process teerakarna/gonymizer \
  --set command=process \
  --set workloadType=job \
  --set mapFile.enabled=true \
  --set mapFile.existingConfigMap=my-mapfile \
  --set persistence.existingClaim=gon-dump-gonymizer
```

### 3. Load anonymized data into target database

```bash
kubectl create secret generic qa-db-credentials \
  --from-literal=password=YOUR_QA_PASSWORD

helm install gon-load teerakarna/gonymizer \
  --set command=load \
  --set workloadType=job \
  --set target.host=qa-db.example.com \
  --set target.database=myapp \
  --set target.username=admin \
  --set target.existingSecret=qa-db-credentials \
  --set persistence.existingClaim=gon-dump-gonymizer
```

## Map file

The map file is a JSON document that defines how each column should be anonymized. Mount it from a ConfigMap:

```bash
kubectl create configmap my-mapfile --from-file=map.json=/path/to/map.json
```

Or inline it in values:

```yaml
mapFile:
  enabled: true
  content: |
    {
      "TableMaps": [
        {
          "TableName": "users",
          "ColumnMaps": [
            { "TableName": "users", "ColumnName": "email", "DataType": "EmailAddress" },
            { "TableName": "users", "ColumnName": "first_name", "DataType": "FirstName" }
          ]
        }
      ]
    }
```

See the [Gonymizer documentation](https://github.com/smithoss/gonymizer/tree/master/docs) for available data types (fakers and scramblers).

## Using a local PostgreSQL database as the anonymization target

Gonymizer does not include a PostgreSQL subchart. To spin up a local target database alongside the load job, deploy PostgreSQL separately using the [Bitnami chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql):

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install qa-db bitnami/postgresql \
  --set auth.database=myapp \
  --set auth.username=admin \
  --set auth.existingSecret=qa-db-credentials

# Then load into it:
helm install gon-load teerakarna/gonymizer \
  --set command=load \
  --set workloadType=job \
  --set target.host=qa-db-postgresql \
  --set target.database=myapp \
  --set target.username=admin \
  --set target.existingSecret=qa-db-credentials
```

## Security notes

| What | Where | Never |
|---|---|---|
| Source DB password | `source.existingSecret` (Secret) | plain values |
| Target DB password | `target.existingSecret` (Secret) | plain values |
| S3 credentials | `s3.existingSecret` (Secret) or IRSA | plain values |

Passwords are injected as `GON_DUMP_PASSWORD`, `GON_MAP_PASSWORD`, or `GON_LOAD_PASSWORD` environment variables. Gonymizer's Viper configuration picks these up automatically via the `GON_` prefix — passwords never appear in container args.

`backoffLimit: 0` is set by default. A partial retry of a dump or anonymization run can produce inconsistent output.

## Values

| Key | Default | Description |
|---|---|---|
| `command` | `dump` | Subcommand: `map` \| `dump` \| `process` \| `load` \| `upload` |
| `workloadType` | `cronjob` | `cronjob` \| `job` |
| `schedule` | `"0 3 * * 0"` | CronJob schedule (weekly Sunday 3am) |
| `backoffLimit` | `0` | Do not retry failed runs |
| `image.repository` | `smithoss/gonymizer` | Official Docker Hub image |
| `image.tag` | `"latest"` | Pin to a specific tag in production |
| `source.host` | `""` | Source DB host |
| `source.port` | `5432` | Source DB port |
| `source.database` | `""` | Source DB name |
| `source.username` | `""` | Source DB username |
| `source.disableSSL` | `false` | Disable SSL (not recommended) |
| `source.existingSecret` | `""` | Secret containing `password` key |
| `target.host` | `""` | Target DB host (load command) |
| `target.existingSecret` | `""` | Secret containing `password` key |
| `mapFile.enabled` | `false` | Mount map file from ConfigMap |
| `mapFile.content` | `""` | Inline map file JSON |
| `mapFile.existingConfigMap` | `""` | Use an existing ConfigMap |
| `configFile.enabled` | `false` | Mount Viper config file |
| `files.dumpFile` | `/data/dump.sql` | Dump file path (inside container) |
| `files.processedFile` | `/data/processed.sql` | Anonymized file path |
| `dump.schema` | `[]` | Schemas to dump |
| `dump.excludeTable` | `[]` | Tables to exclude |
| `process.generateSeed` | `false` | Generate a random seed |
| `process.inclusive` | `false` | Inclusive map file mode |
| `load.skipProcedures` | `false` | Skip stored procedures on load |
| `s3.useIRSA` | `true` | Use IRSA for S3 access |
| `s3.existingSecret` | `""` | Secret with AWS credentials (if not IRSA) |
| `persistence.enabled` | `true` | Create PVC for dump files |
| `persistence.size` | `5Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `logging.level` | `info` | `TRACE` \| `DEBUG` \| `INFO` \| `WARN` \| `ERROR` |
| `logging.format` | `clean` | `json` \| `text` \| `clean` |
| `resources.limits.cpu` | `500m` | CPU limit |
| `resources.limits.memory` | `256Mi` | Memory limit |
