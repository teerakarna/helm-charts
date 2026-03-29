# k6

Scriptable HTTP/S load testing tool ([Grafana k6](https://github.com/grafana/k6)). Runs a JavaScript test script as a Kubernetes Job or CronJob. The script is mounted from a ConfigMap — update it with `--set-file` without reinstalling. Supports VUs, duration, thresholds, and custom checks.

## When to use this chart

| Scenario | Recommended approach |
|---|---|
| Load test a service only reachable via in-cluster DNS (`svc.cluster.local`) | **This chart** |
| Load test an externally reachable URL from CI | [`grafana/run-k6-action`](https://github.com/grafana/run-k6-action) (GitHub Actions) |
| Scheduled recurring load test against an internal service | **This chart** (`workloadType: cronjob`) |
| Distributed cloud load testing from multiple global locations | [Grafana Cloud k6](https://grafana.com/products/cloud/k6/) |

The `run-k6-action` runs k6 directly in the CI runner and posts threshold results back to the workflow summary — use it when the target URL is reachable from GitHub Actions. This chart is the right choice when the target is an internal service and moving load generation inside the cluster avoids the need for ingress, VPN, or a jump host.

Official docs: [k6 documentation](https://grafana.com/docs/k6/) · [run-k6-action](https://github.com/grafana/run-k6-action)

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
helm install load teerakarna/k6 \
  --set env.TARGET_URL=http://my-service.my-namespace.svc.cluster.local/
```

## Usage

```bash
# Run a load test against an in-cluster service
helm install load teerakarna/k6 \
  --set env.TARGET_URL=http://my-service.default.svc.cluster.local/ \
  -n my-namespace
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=load \
  -n my-namespace --timeout=10m
kubectl logs -n my-namespace -l app.kubernetes.io/instance=load

# Use a custom script from a local file
helm install load teerakarna/k6 \
  --set-file script=./my-test.js \
  --set env.TARGET_URL=http://my-service/

# Update the script without reinstalling
helm upgrade load teerakarna/k6 \
  --set-file script=./updated-test.js

# Scheduled weekly load test (CronJob)
helm install load teerakarna/k6 \
  --set workloadType=cronjob \
  --set schedule="0 6 * * 1" \
  --set env.TARGET_URL=http://my-service/

# Trigger a manual run from a CronJob
kubectl create job --from=cronjob/load-k6 load-k6-manual -n my-namespace

# Clean up
helm uninstall load
```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `workloadType` | `job` or `cronjob` | `job` |
| `schedule` | CronJob schedule | `0 6 * * 1` |
| `image.repository` | Image repository | `grafana/k6` |
| `image.tag` | Image tag | Chart appVersion |
| `env` | Environment variables passed as `--env KEY=VALUE` | `{TARGET_URL: http://example.com}` |
| `script` | k6 JavaScript test script | Default HTTP GET + threshold script |
| `resources.limits.cpu` | CPU limit | `1` |
| `resources.limits.memory` | Memory limit | `256Mi` |

## Default script

The default script runs 10 VUs for 30 seconds against `${TARGET_URL}`, asserting `http_req_failed < 1%` and `p95 latency < 500ms`. Replace it with `--set-file script=./your-script.js` for custom scenarios.
