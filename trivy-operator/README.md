# trivy-operator

Kubernetes-native continuous vulnerability and misconfiguration scanner ([Trivy Operator](https://github.com/aquasecurity/trivy-operator) by Aqua Security). Runs as a controller that watches all workloads and automatically scans them, writing results as native CRDs queryable with `kubectl`.

## When to use this chart

| Scenario | Recommended approach |
|---|---|
| Gate a build pipeline — block a deployment if the image has CVEs | [`aquasecurity/trivy-action`](https://github.com/aquasecurity/trivy-action) (GitHub Actions) |
| Always-on scanning of all workloads; results queryable via `kubectl` or a dashboard | **This chart** |
| On-demand or scheduled scan of a specific image or target | [`trivy` chart](../trivy/) |

Choose this chart over the `trivy` chart when you want persistent CRD-based reports, Prometheus metrics (`/metrics`), and automatic re-scanning when workloads change. Choose `trivy-action` in CI to catch vulnerabilities before they reach the cluster at all — the two are complementary, not mutually exclusive.

Official docs: [Trivy Operator documentation](https://aquasecurity.github.io/trivy-operator/) · [trivy-action](https://github.com/aquasecurity/trivy-action)

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
helm install trivy-operator teerakarna/trivy-operator -n trivy-system --create-namespace
```

## Usage

```bash
# Install scanning all namespaces
helm install trivy-operator teerakarna/trivy-operator -n trivy-system --create-namespace

# Restrict to specific namespaces
helm install trivy-operator teerakarna/trivy-operator \
  --set targetNamespaces="default,production" \
  -n trivy-system --create-namespace

# Exclude system namespaces
helm install trivy-operator teerakarna/trivy-operator \
  --set excludeNamespaces="kube-system,kube-public" \
  -n trivy-system --create-namespace

# View vulnerability reports
kubectl get vulnerabilityreports -A
kubectl describe vulnerabilityreport <name> -n <namespace>

# View configuration audit reports
kubectl get configauditreports -A

# View exposed secret reports
kubectl get exposedsecretreports -A

# View RBAC assessment reports
kubectl get rbacassessmentreports -A

# Watch the operator logs
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator -f

# Clean up
helm uninstall trivy-operator -n trivy-system
# CRDs are NOT deleted automatically — remove manually if desired:
# kubectl get crds | grep aquasecurity.github.io | awk '{print $1}' | xargs kubectl delete crd
```

## How it works

The operator watches for Pod, Deployment, DaemonSet, StatefulSet, CronJob, and Job events. When a workload is created or updated, it spawns a short-lived Trivy scan Job in the same namespace. Results are written as CRDs:

| CRD | Scope | Contents |
|---|---|---|
| `VulnerabilityReport` | Namespaced | CVEs in container images |
| `ConfigAuditReport` | Namespaced | Manifest misconfigurations (CIS/NSA) |
| `ExposedSecretReport` | Namespaced | Secrets embedded in image layers |
| `RbacAssessmentReport` | Namespaced | Overly permissive RBAC |
| `InfraAssessmentReport` | Namespaced | Node/kubelet configuration |
| `ClusterVulnerabilityReport` | Cluster | Aggregated image CVEs |
| `ClusterConfigAuditReport` | Cluster | Aggregated config findings |
| `SbomReport` | Namespaced | Software Bill of Materials (opt-in) |

Reports are automatically refreshed after `operator.scannerReportTTL` (default: 24h).

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `targetNamespaces` | Namespaces to scan (empty = all) | `""` |
| `excludeNamespaces` | Namespaces to exclude (comma-separated, glob ok) | `""` |
| `image.repository` | Operator image | `ghcr.io/aquasecurity/trivy-operator` |
| `image.tag` | Operator image tag | Chart appVersion |
| `operator.vulnerabilityScannerEnabled` | Scan images for CVEs | `true` |
| `operator.configAuditScannerEnabled` | Audit workload manifests | `true` |
| `operator.rbacAssessmentScannerEnabled` | Assess RBAC policies | `true` |
| `operator.infraAssessmentScannerEnabled` | Assess node configuration | `true` |
| `operator.exposedSecretScannerEnabled` | Scan image layers for secrets | `true` |
| `operator.sbomGenerationEnabled` | Generate SBOMs (high storage) | `false` |
| `operator.clusterComplianceEnabled` | CIS/NSA compliance reports | `false` |
| `operator.scannerReportTTL` | How long before re-scanning | `24h` |
| `operator.scanJobTimeout` | Max time per scan job | `5m` |
| `operator.scanJobsConcurrentLimit` | Max concurrent scan jobs | `10` |
| `trivy.image.repository` | Trivy scanner image | `aquasec/trivy` |
| `trivy.image.tag` | Trivy scanner tag | `0.69.3` |
| `trivy.severity` | Severity levels to report | `HIGH,CRITICAL` |
| `trivy.ignoreUnfixed` | Skip unfixed vulnerabilities | `false` |
| `trivy.mode` | `Standalone` or `ClientServer` | `Standalone` |
| `trivy.resources.limits.memory` | Memory limit per scan job | `500M` |

## CRD lifecycle

CRDs are installed automatically by Helm from the `crds/` directory and are **not** removed on `helm uninstall`. This is standard Helm behaviour for CRDs, to prevent accidental data loss. To remove them:

```bash
kubectl get crds | grep aquasecurity.github.io | awk '{print $1}' | xargs kubectl delete crd
```
