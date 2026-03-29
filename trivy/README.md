# trivy

Vulnerability scanner ([Trivy](https://github.com/aquasecurity/trivy) by Aqua Security). Runs as a Kubernetes Job or CronJob to scan container images, filesystems, or entire clusters for vulnerabilities, misconfigurations, and secrets. Optionally writes reports to a persistent volume.

## When to use this chart

| Scenario | Recommended approach |
|---|---|
| Gate a build pipeline — block a deployment if the image has CVEs | [`aquasecurity/trivy-action`](https://github.com/aquasecurity/trivy-action) (GitHub Actions) |
| Scheduled drift detection — find CVEs in images already running in the cluster | **This chart** (`workloadType: cronjob`) |
| One-off audit of a specific image or filesystem path | **This chart** (`workloadType: job`) |
| Continuous, always-on scanning of all workloads with kubectl-queryable results | [`trivy-operator` chart](../trivy-operator/) |

The `trivy-action` integrates natively with GitHub Security (SARIF upload, code scanning alerts) and is the right default for CI/CD pipelines. This chart fills the gap it can't: scanning images that are already deployed, or targets that aren't reachable from a CI runner.

Official docs: [Trivy documentation](https://aquasecurity.github.io/trivy/) · [trivy-action](https://github.com/aquasecurity/trivy-action)

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
helm install scan teerakarna/trivy --set target=nginx:latest
```

## Usage

```bash
# Scan a container image for HIGH/CRITICAL CVEs (one-off Job)
helm install scan teerakarna/trivy \
  --set target=nginx:latest \
  --set severity=HIGH,CRITICAL
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=scan --timeout=5m
kubectl logs -l app.kubernetes.io/instance=scan

# Scheduled nightly image scan with JSON report saved to PVC
helm install scan teerakarna/trivy \
  --set workloadType=cronjob \
  --set schedule="0 1 * * *" \
  --set target=myregistry/myapp:latest \
  --set format=json \
  --set persistence.enabled=true

# Scan the entire Kubernetes cluster (requires rbac.create=true)
helm install scan teerakarna/trivy \
  --set scanType=k8s \
  --set target=cluster \
  --set rbac.create=true

# Clean up
helm uninstall scan
```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `workloadType` | `job` or `cronjob` | `job` |
| `schedule` | CronJob schedule | `0 3 * * *` |
| `image.repository` | Image repository | `aquasec/trivy` |
| `image.tag` | Image tag | `0.69.3` |
| `scanType` | Scan type: `image`, `fs`, `repo`, `k8s` | `image` |
| `target` | Target to scan (image ref, path, URL, or `cluster`) | `nginx:latest` |
| `severity` | Severity filter | `HIGH,CRITICAL` |
| `format` | Output format: `table`, `json`, `sarif`, `cyclonedx` | `table` |
| `vulnType` | Vulnerability types: `os,library` | `os,library` |
| `scanners` | Scanners to run: `vuln,secret,misconfig` | `vuln` |
| `ignoreUnfixed` | Skip vulnerabilities without a fix | `true` |
| `exitCode` | Exit code on findings (`0` = complete, `1` = fail Job) | `0` |
| `skipUpdate` | Skip vulnerability DB download | `false` |
| `rbac.create` | Create ClusterRole for `k8s` scan mode | `false` |
| `persistence.enabled` | Save report to a PVC | `false` |
| `persistence.size` | PVC size | `500Mi` |
| `resources.limits.memory` | Memory limit | `1Gi` |
