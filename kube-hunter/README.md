# kube-hunter

Kubernetes penetration testing tool ([kube-hunter](https://github.com/aquasecurity/kube-hunter) by Aqua Security). Runs as a Kubernetes Job or CronJob to hunt for security weaknesses in your cluster from within the pod's network. Results are printed to stdout in table, JSON, or YAML format.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install hunter teerakarna/kube-hunter
```

## Usage examples

### One-off Job — hunt from inside the cluster (default)

```bash
helm install hunter teerakarna/kube-hunter
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=hunter --timeout=30m
kubectl logs -l app.kubernetes.io/instance=hunter
```

### Scheduled weekly hunt (CronJob)

```bash
helm install hunter teerakarna/kube-hunter \
  --set workloadType=cronjob \
  --set schedule="0 3 * * 0"
```

### Scan a specific CIDR range

```bash
helm install hunter teerakarna/kube-hunter \
  --set scope=cidr \
  --set cidr="10.0.0.0/8"
```

### Save results locally

```bash
kubectl logs \
  $(kubectl get pod -l app.kubernetes.io/instance=hunter -o jsonpath="{.items[0].metadata.name}") \
  > kube-hunter-results.json
```

## Active hunting

Active hunting attempts to exploit discovered vulnerabilities and **can cause cluster disruption**. Only enable in dedicated test clusters with explicit approval.

```bash
# Only in isolated test clusters:
helm install hunter teerakarna/kube-hunter \
  --set active=true
```

## Security notes

kube-hunter scans the network from the pod's perspective — it does not need the Kubernetes API token. `automountServiceAccountToken: false` is set at both the ServiceAccount and pod levels.

The pod's security context enforces `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, and drops all Linux capabilities.

`backoffLimit: 0` and `concurrencyPolicy: Forbid` are set by default to prevent overlapping or retried hunts.

## Values

| Key | Default | Description |
|---|---|---|
| `workloadType` | `job` | `job` \| `cronjob` |
| `schedule` | `"0 3 * * 0"` | CronJob schedule (weekly Sunday 3am) |
| `backoffLimit` | `0` | Do not retry failed runs |
| `image.repository` | `aquasec/kube-hunter` | Official Aqua Security image |
| `image.tag` | `""` | Defaults to appVersion (latest) — pin in production |
| `scope` | `pod` | `pod` (in-cluster) \| `cidr` (network range) |
| `cidr` | `""` | Network range to scan when scope=cidr (e.g. `10.0.0.0/8`) |
| `active` | `false` | Enable active hunting — can cause disruption |
| `report` | `json` | `table` \| `json` \| `yaml` |
| `statistics` | `false` | Print hunt statistics |
