# toxiproxy

Network fault injection proxy ([Toxiproxy](https://github.com/Shopify/toxiproxy) by Shopify). Deploys a configurable TCP proxy that can inject latency, bandwidth limits, packet loss, timeouts, and connection resets — useful for resilience testing, chaos engineering, and verifying timeout/retry behaviour of in-cluster services.

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
helm install toxi teerakarna/toxiproxy \
  --set 'proxies[0].name=redis' \
  --set 'proxies[0].listen=0.0.0.0:26379' \
  --set 'proxies[0].upstream=redis-master.default.svc.cluster.local:6379' \
  --set 'proxies[0].enabled=true'
```

## Usage

```bash
# Deploy with a Redis proxy
helm install toxi teerakarna/toxiproxy \
  --set 'proxies[0].name=redis' \
  --set 'proxies[0].listen=0.0.0.0:26379' \
  --set 'proxies[0].upstream=redis-master.default.svc.cluster.local:6379' \
  --set 'proxies[0].enabled=true' \
  -n my-namespace

# Access the Toxiproxy API
kubectl port-forward -n my-namespace svc/toxi-toxiproxy 8474:8474

# Add 100ms latency to the redis proxy
curl -X POST http://localhost:8474/proxies/redis/toxics \
  -d '{"name":"latency","type":"latency","attributes":{"latency":100,"jitter":10}}'

# Limit bandwidth to 100KB/s
curl -X POST http://localhost:8474/proxies/redis/toxics \
  -d '{"name":"bandwidth","type":"bandwidth","attributes":{"rate":100}}'

# Remove a toxic
curl -X DELETE http://localhost:8474/proxies/redis/toxics/latency

# List all proxies
curl http://localhost:8474/proxies

# Point your app at Toxiproxy instead of the real service
# redis-master.default.svc.cluster.local:6379 -> toxi-toxiproxy.default.svc.cluster.local:26379
```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `image.repository` | Image repository | `ghcr.io/shopify/toxiproxy` |
| `image.tag` | Image tag | Chart appVersion |
| `replicaCount` | Number of replicas | `1` |
| `proxies` | List of proxy definitions | Single example proxy on port 22000 |
| `proxies[].name` | Proxy identifier (used in API calls) | — |
| `proxies[].listen` | Address to bind (e.g. `0.0.0.0:26379`) | — |
| `proxies[].upstream` | Backend to proxy to (`host:port`) | — |
| `proxies[].enabled` | Enable proxy on startup | `true` |
| `service.type` | Service type | `ClusterIP` |
| `service.apiPort` | Toxiproxy REST API port | `8474` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `64Mi` |

## Available toxics

`latency`, `bandwidth`, `slow_close`, `timeout`, `slicer`, `limit_data` — see the [Toxiproxy documentation](https://github.com/Shopify/toxiproxy#toxics) for full details and attributes.
