# bombardier

Fast HTTP/S benchmarking tool ([bombardier](https://github.com/codesenberg/bombardier) by Evgeny Serlachev). Runs as a Kubernetes Job or CronJob to load-test in-cluster services and measure throughput, latency, and error rates. Pairs naturally with the `echoserver` chart.

## Prerequisites

No official bombardier container image exists. Build the included `Dockerfile` using the GitHub Actions build pipeline, then push it to a registry your cluster can pull from.

**Build the image:**

```bash
# Trigger the manual workflow in GitHub Actions:
# Actions → Build bombardier Image → Run workflow → enter version → Run

# Or build locally:
docker build \
  --build-arg BOMBARDIER_VERSION=1.2.6 \
  -t ghcr.io/YOUR_USERNAME/bombardier:1.2.6 \
  bombardier/docker/
docker push ghcr.io/YOUR_USERNAME/bombardier:1.2.6
```

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=http://my-service.my-namespace.svc.cluster.local/
```

## Usage examples

### Run a 30-second load test

```bash
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=http://echo.default.svc.cluster.local/ \
  --set bombardier.duration=30s \
  --set bombardier.connections=50
```

### Run exactly N requests

```bash
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=http://echo.default.svc.cluster.local/ \
  --set bombardier.requests=10000
```

### Rate-limited test

```bash
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=http://echo.default.svc.cluster.local/ \
  --set bombardier.rate=100 \
  --set bombardier.duration=60s
```

### Scheduled weekly baseline (CronJob)

```bash
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set workloadType=cronjob \
  --set schedule="0 6 * * 1" \
  --set target.url=http://my-service.my-namespace.svc.cluster.local/healthz
```

### Test with HTTPS and custom headers

```bash
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=https://my-service.my-namespace.svc.cluster.local/ \
  --set bombardier.insecure=true \
  --set 'bombardier.headers.Authorization=Bearer mytoken' \
  --set 'bombardier.headers.X-Request-ID=test'
```

### View results

```bash
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=load --timeout=10m
kubectl logs -l app.kubernetes.io/instance=load
```

## Security notes

`automountServiceAccountToken: false` — bombardier sends HTTP requests to the target service only; it does not need Kubernetes API access.

`backoffLimit: 0` — a failed load test should not retry automatically, as retries may skew results or cause unexpected load.

## Values

| Key | Default | Description |
|---|---|---|
| `workloadType` | `job` | `job` \| `cronjob` |
| `schedule` | `"0 6 * * 1"` | CronJob schedule (weekly Monday 6am) |
| `backoffLimit` | `0` | Do not retry failed runs |
| `image.repository` | `ghcr.io/teerakarna/bombardier` | Image — must be built first |
| `image.tag` | `""` | Defaults to appVersion (`1.2.6`) |
| `target.url` | `""` | **Required.** Target URL to benchmark |
| `bombardier.connections` | `125` | Concurrent connections |
| `bombardier.requests` | `null` | Number of requests (mutually exclusive with duration) |
| `bombardier.duration` | `"30s"` | Test duration (used when requests is null) |
| `bombardier.rate` | `null` | Max requests per second (null = unlimited) |
| `bombardier.method` | `GET` | HTTP method |
| `bombardier.headers` | `{}` | HTTP headers (key: value map) |
| `bombardier.body` | `""` | Request body |
| `bombardier.timeout` | `"2s"` | Request timeout |
| `bombardier.insecure` | `false` | Skip TLS verification |
| `bombardier.http2` | `true` | Use HTTP/2 when available |
| `bombardier.latencies` | `false` | Print latency distribution |
| `bombardier.format` | `plain-text` | `plain-text` \| `json` \| `csv` |
| `resources.limits.cpu` | `"1"` | CPU limit |
| `resources.limits.memory` | `256Mi` | Memory limit |
