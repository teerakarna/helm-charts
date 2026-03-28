# netshoot

Network troubleshooting pod based on [nicolaka/netshoot](https://github.com/nicolaka/netshoot). Deploy into any namespace and exec in to diagnose DNS, connectivity, routing, and network policy issues.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install netshoot teerakarna/netshoot -n <namespace>
```

## Uninstall

```bash
helm uninstall netshoot -n <namespace>
```

## Usage examples

### Basic — exec in and start diagnosing

```bash
helm install netshoot teerakarna/netshoot -n default
kubectl exec -it -n default \
  $(kubectl get pod -n default -l app.kubernetes.io/instance=netshoot -o jsonpath="{.items[0].metadata.name}") \
  -- bash
```

### Test DNS resolution

```bash
# Inside the pod:
dig my-service.my-namespace.svc.cluster.local
nslookup kubernetes.default.svc.cluster.local
```

### Test connectivity and latency

```bash
# Inside the pod:
ping -c 4 my-service.my-namespace.svc.cluster.local
traceroute my-service.my-namespace.svc.cluster.local
curl -sv http://my-service/health
```

### Capture traffic with tcpdump

```bash
# Inside the pod (requires NET_RAW):
tcpdump -i eth0 -n port 80
```

### Test network policies

Deploy into the target namespace and attempt connections that should or should not be allowed:

```bash
helm install probe teerakarna/netshoot -n restricted-namespace
kubectl exec -it -n restricted-namespace \
  $(kubectl get pod -n restricted-namespace -l app.kubernetes.io/instance=probe -o jsonpath="{.items[0].metadata.name}") \
  -- bash

# Inside the pod:
curl -sv --max-time 3 http://blocked-service/  # expect timeout
curl -sv --max-time 3 http://allowed-service/  # expect 200
```

### Run a one-shot diagnostic (non-interactively)

```bash
helm install probe teerakarna/netshoot -n default \
  --set command='["curl"]' \
  --set 'args=["-sv", "http://my-service/health"]'
kubectl logs -n default -l app.kubernetes.io/instance=probe
```

## Capabilities

netshoot requires elevated Linux capabilities for its network diagnostic tools:

| Capability | Used by |
|---|---|
| `NET_RAW` | ping, traceroute, tcpdump |
| `NET_ADMIN` | ip, iptables, tc, bridge |

Reduce `securityContext.capabilities.add` if you only need basic connectivity checks (e.g. curl/dig only need neither).

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of pod replicas |
| `image.repository` | `nicolaka/netshoot` | Container image repository |
| `image.tag` | `""` | Image tag — defaults to `appVersion` (`latest`); pin a specific tag in production |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `nameOverride` | `""` | Override chart name |
| `fullnameOverride` | `""` | Override fully qualified app name |
| `serviceAccount.create` | `true` | Create a ServiceAccount |
| `serviceAccount.annotations` | `{}` | Annotations for the ServiceAccount |
| `serviceAccount.name` | `""` | ServiceAccount name (generated if empty) |
| `podAnnotations` | `{}` | Annotations added to pods |
| `podLabels` | `{}` | Extra labels added to pods |
| `podSecurityContext.runAsNonRoot` | `false` | Some tools (tcpdump, iptables) require root |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `securityContext.capabilities.drop` | `["ALL"]` | Drop all capabilities first |
| `securityContext.capabilities.add` | `["NET_RAW", "NET_ADMIN"]` | Add back only what's needed |
| `command` | `["sleep"]` | Container command — override to run a specific tool |
| `args` | `["infinity"]` | Container args — override to pass tool arguments |
| `resources.limits.cpu` | `200m` | CPU limit |
| `resources.limits.memory` | `256Mi` | Memory limit |
| `resources.requests.cpu` | `50m` | CPU request |
| `resources.requests.memory` | `64Mi` | Memory request |
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
