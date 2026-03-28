# sleep

Minimal long-running pod for exec-based debugging. Deploys an Alpine container that sleeps indefinitely — exec in to run commands from inside a namespace without deploying a real application.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install debug teerakarna/sleep -n <namespace>
```

## Uninstall

```bash
helm uninstall debug -n <namespace>
```

## Usage examples

### Exec in and run commands

```bash
helm install debug teerakarna/sleep -n default
kubectl exec -it -n default \
  $(kubectl get pod -n default -l app.kubernetes.io/instance=debug -o jsonpath="{.items[0].metadata.name}") \
  -- sh
```

Once inside, you can test DNS, call internal services, inspect environment variables, or run any tool available in Alpine.

### Install in a specific namespace to test network policies

```bash
helm install probe teerakarna/sleep -n my-app
kubectl exec -it -n my-app \
  $(kubectl get pod -n my-app -l app.kubernetes.io/instance=probe -o jsonpath="{.items[0].metadata.name}") \
  -- sh

# Inside the pod — test connectivity to other services in the namespace:
wget -qO- http://my-service/
```

### Install apk packages inside the container

```bash
# Once exec'd in:
apk add --no-cache curl bind-tools
curl -s http://my-service/health
dig my-service.my-app.svc.cluster.local
```

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of pod replicas |
| `image.repository` | `alpine` | Container image repository |
| `image.tag` | `""` | Image tag — defaults to `appVersion` (3) |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `nameOverride` | `""` | Override chart name |
| `fullnameOverride` | `""` | Override fully qualified app name |
| `serviceAccount.create` | `true` | Create a ServiceAccount |
| `serviceAccount.annotations` | `{}` | Annotations for the ServiceAccount |
| `serviceAccount.name` | `""` | ServiceAccount name (generated if empty) |
| `podAnnotations` | `{}` | Annotations added to pods |
| `podLabels` | `{}` | Extra labels added to pods |
| `podSecurityContext.runAsNonRoot` | `true` | Enforce non-root execution |
| `podSecurityContext.runAsUser` | `65534` | UID to run as (`nobody`) |
| `podSecurityContext.runAsGroup` | `65534` | GID to run as |
| `podSecurityContext.fsGroup` | `65534` | fsGroup for volume mounts |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | Seccomp profile |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `securityContext.readOnlyRootFilesystem` | `true` | Read-only root filesystem |
| `securityContext.capabilities.drop` | `["ALL"]` | Drop all Linux capabilities |
| `resources.limits.cpu` | `50m` | CPU limit |
| `resources.limits.memory` | `32Mi` | Memory limit |
| `resources.requests.cpu` | `5m` | CPU request |
| `resources.requests.memory` | `8Mi` | Memory request |
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
