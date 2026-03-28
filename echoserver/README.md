# echoserver

HTTP echo server for testing ingress controllers, load balancers, and network policies in Kubernetes. Returns request headers, body, and environment info on every HTTP request — useful for verifying routing, header injection, TLS termination, and service discovery.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install echo teerakarna/echoserver
```

## Uninstall

```bash
helm uninstall echo
```

## Usage examples

### Basic — port-forward and test

```bash
helm install echo teerakarna/echoserver
kubectl port-forward svc/echo-echoserver 8080:80
curl http://localhost:8080/
```

The response includes the request method, URI, headers, and the pod's environment variables. Useful for confirming which pod served the request, what headers were injected, and whether a proxy is adding/stripping headers.

### Test ingress routing

```bash
helm install echo teerakarna/echoserver \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=echo.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"

curl http://echo.example.com/
curl http://echo.example.com/some/path -H "X-Test-Header: hello"
```

### Test load balancing across replicas

```bash
helm install echo teerakarna/echoserver --set replicaCount=3

# Hostname in the response changes across requests — confirms load balancing
for i in $(seq 1 6); do
  curl -s http://localhost:8080/ | grep "Hostname"
done
```

### Test with HPA

```bash
helm install echo teerakarna/echoserver \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10 \
  --set autoscaling.targetCPUUtilizationPercentage=50
```

### Run Helm tests

```bash
helm test echo
```

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of pod replicas |
| `image.repository` | `registry.k8s.io/echoserver` | Container image repository |
| `image.tag` | `""` | Image tag — defaults to `appVersion` |
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
| `podSecurityContext.runAsUser` | `1000` | UID to run as |
| `podSecurityContext.runAsGroup` | `1000` | GID to run as |
| `podSecurityContext.fsGroup` | `1000` | fsGroup for volume mounts |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | Seccomp profile |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `securityContext.readOnlyRootFilesystem` | `true` | Read-only root filesystem |
| `securityContext.capabilities.drop` | `["ALL"]` | Drop all Linux capabilities |
| `service.type` | `ClusterIP` | Service type (`ClusterIP`, `NodePort`, `LoadBalancer`) |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable Ingress |
| `ingress.className` | `""` | `ingressClassName` (e.g. `nginx`, `traefik`) |
| `ingress.annotations` | `{}` | Ingress annotations |
| `ingress.hosts` | see values.yaml | Ingress host and path rules |
| `ingress.tls` | `[]` | TLS configuration |
| `resources.limits.cpu` | `100m` | CPU limit |
| `resources.limits.memory` | `64Mi` | Memory limit |
| `resources.requests.cpu` | `10m` | CPU request |
| `resources.requests.memory` | `32Mi` | Memory request |
| `autoscaling.enabled` | `false` | Enable HorizontalPodAutoscaler |
| `autoscaling.minReplicas` | `1` | HPA minimum replicas |
| `autoscaling.maxReplicas` | `10` | HPA maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | HPA CPU target |
| `autoscaling.targetMemoryUtilizationPercentage` | `""` | HPA memory target (disabled by default) |
| `livenessProbe.initialDelaySeconds` | `5` | Liveness probe initial delay |
| `livenessProbe.periodSeconds` | `10` | Liveness probe period |
| `livenessProbe.timeoutSeconds` | `2` | Liveness probe timeout |
| `livenessProbe.failureThreshold` | `3` | Liveness probe failure threshold |
| `readinessProbe.initialDelaySeconds` | `5` | Readiness probe initial delay |
| `readinessProbe.periodSeconds` | `10` | Readiness probe period |
| `readinessProbe.timeoutSeconds` | `2` | Readiness probe timeout |
| `readinessProbe.failureThreshold` | `3` | Readiness probe failure threshold |
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
