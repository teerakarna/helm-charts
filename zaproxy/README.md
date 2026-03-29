# zaproxy

Web application security scanner ([OWASP ZAP](https://www.zaproxy.org/)). Runs as a Kubernetes Job or CronJob using ZAP's [Automation Framework](https://www.zaproxy.org/docs/desktop/addons/automation-framework/). The scan plan is mounted from a ConfigMap — update it with `--set-file` without reinstalling. The default plan runs a traditional spider and passive scan, making it safe for use against any in-cluster service.

## When to use this chart

| Scenario | Recommended approach |
|---|---|
| Scan a service only reachable via in-cluster DNS (`svc.cluster.local`) | **This chart** |
| Scan a publicly or externally reachable staging URL from CI | Official ZAP GitHub Actions (see below) |
| Scheduled recurring DAST scan of an internal service | **This chart** (`workloadType: cronjob`) |

For publicly reachable targets, the official ZAP GitHub Actions are the better fit: they post results as PR annotations, upload SARIF to GitHub Advanced Security, and don't require cluster access.

| Action | Use for |
|---|---|
| [`zaproxy/action-baseline-scan`](https://github.com/zaproxy/action-baseline-scan) | Passive scan only — safe for any environment |
| [`zaproxy/action-full-scan`](https://github.com/zaproxy/action-full-scan) | Spider + passive + active scan — test environments only |
| [`zaproxy/action-api-scan`](https://github.com/zaproxy/action-api-scan) | OpenAPI/GraphQL/SOAP API targets |

Official docs: [ZAP Automation Framework](https://www.zaproxy.org/docs/desktop/addons/automation-framework/) · [ZAP GitHub Actions](https://www.zaproxy.org/docs/docker/github-actions/)

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
helm install zap teerakarna/zaproxy \
  --set target.url=http://my-service.my-namespace.svc.cluster.local/
```

## Usage

```bash
# One-off passive scan against an in-cluster service
helm install zap teerakarna/zaproxy \
  --set target.url=http://my-service.default.svc.cluster.local/ \
  -n my-namespace
kubectl logs -n my-namespace -l app.kubernetes.io/instance=zap -f

# Save the HTML report to a PVC
helm install zap teerakarna/zaproxy \
  --set target.url=http://my-service/ \
  --set persistence.enabled=true \
  -n my-namespace

# Use a custom automation plan from a local file
helm install zap teerakarna/zaproxy \
  --set target.url=http://my-service/ \
  --set-file plan=./my-plan.yaml

# Update the plan without reinstalling
helm upgrade zap teerakarna/zaproxy \
  --set-file plan=./updated-plan.yaml

# Scheduled weekly scan (CronJob)
helm install zap teerakarna/zaproxy \
  --set workloadType=cronjob \
  --set schedule="0 2 * * 1" \
  --set target.url=http://my-service/

# Trigger a manual run from a CronJob
kubectl create job --from=cronjob/zap-zaproxy zap-zaproxy-manual -n my-namespace

# Clean up
helm uninstall zap
```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `workloadType` | `job` or `cronjob` | `job` |
| `schedule` | CronJob schedule | `0 2 * * 1` |
| `image.repository` | Image repository | `ghcr.io/zaproxy/zaproxy` |
| `image.tag` | Image tag (`stable` tracks latest stable release) | `stable` |
| `target.url` | Target URL — injected as `${TARGET_URL}` in the plan | `http://example.com` |
| `plan` | ZAP Automation Framework plan (YAML string) | Spider + passive scan + HTML report |
| `activeDeadlineSeconds` | Max seconds before Job is terminated (`0` = unlimited) | `0` |
| `persistence.enabled` | Save reports to a PVC | `false` |
| `persistence.size` | PVC size | `500Mi` |
| `resources.limits.cpu` | CPU limit | `1` |
| `resources.limits.memory` | Memory limit (`2Gi` minimum recommended) | `2Gi` |

## Default plan

The default plan runs:
1. **Spider** — crawls the target for up to 2 minutes
2. **Passive scan** — analyses captured traffic without sending additional requests (up to 5 minutes)
3. **Report** — writes an HTML report to `/zap/wrk/reports/`

To add an active scan (sends attack traffic — use only in dedicated test environments), append a `activeScan` job to your custom plan.

## Environment variables in plans

The `TARGET_URL` environment variable is always available in the plan as `${TARGET_URL}`, derived from `target.url`. For advanced parameterisation, override the entire `plan` with a custom automation YAML that uses ZAP's native `env.vars` block.
