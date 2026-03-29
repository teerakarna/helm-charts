# kube-bench

CIS Kubernetes Benchmark auditing tool ([kube-bench](https://github.com/aquasecurity/kube-bench) by Aqua Security). Runs as a Kubernetes Job or CronJob to check whether your cluster is deployed according to CIS security best practices, then writes a JSON/JUnit/ASFF results file to a persistent volume.

## Why a Helm chart and not a CI/CD job

kube-bench reads node-level configuration files (`/var/lib/kubelet/config.yaml`, `/etc/kubernetes/`) and cluster API state that are only accessible from within the cluster itself. There is no meaningful CI/CD equivalent — it must run on the cluster as a privileged Job. The chart is the standard deployment method recommended in the [kube-bench documentation](https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md#running-in-a-kubernetes-cluster).

Official docs: [kube-bench](https://github.com/aquasecurity/kube-bench) · [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install kb teerakarna/kube-bench
```

## Usage examples

### One-off Job (default)

```bash
helm install kb teerakarna/kube-bench
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=kb --timeout=10m
kubectl logs -l app.kubernetes.io/instance=kb --tail=200
```

### Scheduled weekly scan (CronJob)

```bash
helm install kb teerakarna/kube-bench \
  --set workloadType=cronjob \
  --set schedule="0 4 * * 0"
```

### Target specific checks

```bash
# Node-level checks only
helm install kb teerakarna/kube-bench \
  --set "targets={node}"

# Control plane + policies
helm install kb teerakarna/kube-bench \
  --set "targets={master,policies}"
```

### Use a managed Kubernetes benchmark profile

```bash
# EKS
helm install kb teerakarna/kube-bench --set benchmark=eks

# AKS
helm install kb teerakarna/kube-bench --set benchmark=aks

# GKE
helm install kb teerakarna/kube-bench --set benchmark=gke
```

### Read results from the PVC

```bash
helm install debug teerakarna/sleep -n <namespace>
kubectl exec -it -n <namespace> \
  $(kubectl get pod -n <namespace> -l app.kubernetes.io/instance=debug -o jsonpath="{.items[0].metadata.name}") \
  -- sh
# cat /reports/results.json
```

## Security notes

kube-bench queries the Kubernetes API to read cluster state — it needs a service account token. The chart creates a `ClusterRole` with read-only access to the resources kube-bench checks, and sets `automountServiceAccountToken: true` at the pod level (the ServiceAccount itself has it disabled as a secure baseline).

The ClusterRole grants `get`/`list` only — no write access, no exec access. Set `rbac.create: false` to bring your own ClusterRole.

`backoffLimit: 0` is set by default. A failed partial run should not silently retry.

## Values

| Key | Default | Description |
|---|---|---|
| `workloadType` | `job` | `job` \| `cronjob` |
| `schedule` | `"0 4 * * 0"` | CronJob schedule (weekly Sunday 4am) |
| `backoffLimit` | `0` | Do not retry failed runs |
| `image.repository` | `aquasec/kube-bench` | Official Aqua Security image |
| `image.tag` | `"v0.15.0"` | Pin to a specific release |
| `rbac.create` | `true` | Create ClusterRole + ClusterRoleBinding |
| `targets` | `[]` | Targets: `node`, `master`, `controlplane`, `etcd`, `policies`, `managedservices` |
| `benchmark` | `""` | Benchmark profile: `cis-1.8`, `eks`, `aks`, `gke`, etc. (auto-detect if empty) |
| `kubernetesVersion` | `""` | Override K8s version for benchmark selection |
| `outputFormat` | `json` | `text` \| `json` \| `junit` \| `asff` |
| `persistence.enabled` | `true` | Write results to PVC |
| `persistence.size` | `100Mi` | PVC size |
| `persistence.existingClaim` | `""` | Use an existing PVC |
