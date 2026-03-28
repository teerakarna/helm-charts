# dbclient

Database client debug pod — `psql`, `redis-cli`, and `mysql` in one Alpine container. Deploy into any namespace and exec in to run queries, inspect schemas, or debug connectivity — without installing anything on the node.

## Prerequisites

No official all-in-one database client image exists. Build the included `Dockerfile` using the GitHub Actions build pipeline, then push it to a registry your cluster can pull from.

**Build the image:**

```bash
# Trigger the manual workflow in GitHub Actions:
# Actions → Build dbclient Image → Run workflow → Run

# Or build locally:
docker build -t ghcr.io/YOUR_USERNAME/dbclient:latest dbclient/docker/
docker push ghcr.io/YOUR_USERNAME/dbclient:latest
```

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install db teerakarna/dbclient \
  --set image.repository=ghcr.io/YOUR_USERNAME/dbclient \
  -n <namespace>
```

## Exec in

```bash
kubectl exec -it -n <namespace> \
  $(kubectl get pod -n <namespace> -l app.kubernetes.io/instance=db -o jsonpath="{.items[0].metadata.name}") \
  -- bash
```

## Quick connect examples

### PostgreSQL

```bash
# Using environment variables
helm install db teerakarna/dbclient \
  --set image.repository=ghcr.io/YOUR_USERNAME/dbclient \
  --set env[0].name=PGHOST,env[0].value=mydb.namespace.svc.cluster.local \
  --set env[1].name=PGUSER,env[1].value=myuser \
  --set env[2].name=PGDATABASE,env[2].value=mydb

# Injecting the password from a Secret
helm install db teerakarna/dbclient \
  --set image.repository=ghcr.io/YOUR_USERNAME/dbclient \
  --set env[0].name=PGPASSWORD \
  --set env[0].valueFrom.secretKeyRef.name=my-db-secret \
  --set env[0].valueFrom.secretKeyRef.key=password

# Then inside the pod:
psql -h mydb.namespace.svc.cluster.local -U myuser -d mydb
```

### Redis

```bash
redis-cli -h redis.namespace.svc.cluster.local
redis-cli -h redis.namespace.svc.cluster.local -a $REDIS_PASSWORD
```

### MySQL / MariaDB

```bash
mysql -h mysql.namespace.svc.cluster.local -u myuser -p mydb
```

## Run a one-off query

```bash
helm install db teerakarna/dbclient \
  --set image.repository=ghcr.io/YOUR_USERNAME/dbclient \
  --set command=null \
  --set "args={psql,-h,mydb.svc,-U,myuser,-c,SELECT version();}"
```

## Security notes

| What | Where | Never |
|---|---|---|
| DB passwords | `env[].valueFrom.secretKeyRef` | plain values |
| Redis auth | `env[].valueFrom.secretKeyRef` | plain values |

`automountServiceAccountToken: false` — the debug pod has no Kubernetes API access.

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of replicas |
| `image.repository` | `ghcr.io/teerakarna/dbclient` | Image — must be built first |
| `image.tag` | `""` | Defaults to appVersion (latest) |
| `command` | `["sleep"]` | Container command |
| `args` | `["infinity"]` | Container args |
| `env` | `[]` | Environment variables (use `secretKeyRef` for credentials) |
| `resources.limits.cpu` | `200m` | CPU limit |
| `resources.limits.memory` | `128Mi` | Memory limit |
