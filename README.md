# helm-charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/teerakarna)](https://artifacthub.io/packages/search?repo=teerakarna)

Helm charts for Kubernetes. Hosted on GitHub Pages via [chart-releaser](https://github.com/helm/chart-releaser).

## Add the repository

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update
```

## Available charts

| Chart | Description | Version |
|---|---|---|
| [echoserver](./echoserver/) | HTTP echo server for testing ingress, load balancing, and network policies | 0.2.0 |
| [netshoot](./netshoot/) | Network troubleshooting pod (nicolaka/netshoot) — DNS, connectivity, routing, network policy | 0.1.0 |
| [sleep](./sleep/) | Minimal Alpine pod that sleeps indefinitely — exec in to run commands inside a namespace | 0.1.0 |
| [dbclient](./dbclient/) | Database client debug pod — psql, redis-cli, and mysql in one Alpine container | 0.1.0 |
| [scoutsuite](./scoutsuite/) | Multi-cloud security auditing (ScoutSuite) — CronJob/Job for AWS, GCP, Azure and more | 0.1.0 |
| [kube-bench](./kube-bench/) | CIS Kubernetes Benchmark auditing (kube-bench) — Job/CronJob with ClusterRole | 0.1.0 |
| [kube-hunter](./kube-hunter/) | Kubernetes penetration testing (kube-hunter) — hunt for security weaknesses in-cluster | 0.1.0 |
| [gonymizer](./gonymizer/) | PostgreSQL data anonymization (Gonymizer) — dump, anonymize, and reload PII/PHI for QA | 0.1.0 |
| [bombardier](./bombardier/) | Fast HTTP/S load testing (bombardier) — Job/CronJob to benchmark in-cluster services | 0.1.0 |
| [trivy](./trivy/) | Vulnerability scanner (Trivy) — Job/CronJob to scan images, filesystems, or entire clusters | 0.1.0 |
| [k6](./k6/) | Scriptable load testing (Grafana k6) — Job/CronJob with a ConfigMap-mounted JS test script | 0.1.0 |
| [toxiproxy](./toxiproxy/) | Network fault injection proxy (Toxiproxy) — Deployment to inject latency, packet loss, and timeouts | 0.1.0 |
| [zaproxy](./zaproxy/) | Web application security scanner (OWASP ZAP) — Job/CronJob with Automation Framework plan | 0.1.0 |

## Usage

```bash
# HTTP echo server — test ingress and routing
helm install echo teerakarna/echoserver
kubectl port-forward svc/echo-echoserver 8080:80
curl http://localhost:8080/

# Network troubleshooting pod — exec in to diagnose DNS/connectivity issues
helm install netshoot teerakarna/netshoot -n <namespace>
kubectl exec -it -n <namespace> \
  $(kubectl get pod -n <namespace> -l app.kubernetes.io/instance=netshoot -o jsonpath="{.items[0].metadata.name}") \
  -- bash

# Minimal debug pod — exec in to run arbitrary commands inside a namespace
helm install debug teerakarna/sleep -n <namespace>
kubectl exec -it -n <namespace> \
  $(kubectl get pod -n <namespace> -l app.kubernetes.io/instance=debug -o jsonpath="{.items[0].metadata.name}") \
  -- sh

# Database client pod — psql, redis-cli, mysql
helm install db teerakarna/dbclient \
  --set image.repository=ghcr.io/YOUR_USERNAME/dbclient \
  -n <namespace>
kubectl exec -it -n <namespace> \
  $(kubectl get pod -n <namespace> -l app.kubernetes.io/instance=db -o jsonpath="{.items[0].metadata.name}") \
  -- bash

# CIS Kubernetes Benchmark — one-off audit
helm install kb teerakarna/kube-bench
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=kb --timeout=10m
kubectl logs -l app.kubernetes.io/instance=kb

# Kubernetes penetration test — hunt from inside the cluster
helm install hunter teerakarna/kube-hunter
kubectl logs -l app.kubernetes.io/instance=hunter

# HTTP load test — benchmark an in-cluster service
helm install load teerakarna/bombardier \
  --set image.repository=ghcr.io/YOUR_USERNAME/bombardier \
  --set target.url=http://echo-echoserver.default.svc.cluster.local/
kubectl logs -l app.kubernetes.io/instance=load

# Vulnerability scan — scan an image for HIGH/CRITICAL CVEs
helm install scan teerakarna/trivy \
  --set target=nginx:latest
kubectl logs -l app.kubernetes.io/instance=scan

# Scriptable load test — run a k6 JS script against an in-cluster service
helm install k6 teerakarna/k6 \
  --set env.TARGET_URL=http://echo-echoserver.default.svc.cluster.local/
kubectl logs -l app.kubernetes.io/instance=k6

# DAST scan — spider and passive-scan a service with OWASP ZAP
helm install zap teerakarna/zaproxy \
  --set target.url=http://echo-echoserver.default.svc.cluster.local/
kubectl logs -l app.kubernetes.io/instance=zap -f

# Network fault injection — wrap a service with Toxiproxy for chaos testing
helm install toxi teerakarna/toxiproxy \
  --set 'proxies[0].name=redis' \
  --set 'proxies[0].listen=0.0.0.0:26379' \
  --set 'proxies[0].upstream=redis-master.default.svc.cluster.local:6379' \
  --set 'proxies[0].enabled=true'
# Add latency via the API:
kubectl port-forward svc/toxi-toxiproxy 8474:8474
curl -X POST http://localhost:8474/proxies/redis/toxics \
  -d '{"name":"latency","type":"latency","attributes":{"latency":100}}'
```

## Development

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) >= 3.14
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin
- [chart-testing (ct)](https://github.com/helm/chart-testing)

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
pip install yamllint
```

### Lint a chart

```bash
ct lint --config ct.yaml --charts <chart-name>
ct lint --config ct.yaml  # lint all changed charts
```

### Run unit tests

```bash
helm unittest <chart-name>
helm unittest kube-bench kube-hunter dbclient bombardier
```

### Render templates locally

```bash
helm template my-release <chart-name>
helm template my-release kube-bench
helm template my-release bombardier --set target.url=http://example.com/
```

## Releasing

Charts are released automatically on merge to `main` via [chart-releaser-action](https://github.com/helm/chart-releaser-action).

To release a new chart version:
1. Bump `version` in the chart's `Chart.yaml`
2. Open a PR — CI lints and runs unit tests
3. Merge to `main` — chart-releaser packages the chart, creates a GitHub Release, and updates the Helm repository index on the `gh-pages` branch

> **First-time setup:** After the first release workflow runs and creates the `gh-pages` branch, enable GitHub Pages in the repo settings pointing to that branch.

## Supply chain security

All chart packages and Docker images are signed with [cosign](https://github.com/sigstore/cosign) using keyless signing (GitHub Actions OIDC). No key management required — signatures are verifiable against the public [Rekor](https://rekor.sigstore.dev) transparency log.

### Verify a chart package

Download the `.tgz` and `.bundle` files from the GitHub Release assets, then:

```bash
cosign verify-blob \
  --bundle kube-bench-0.1.0.tgz.bundle \
  --certificate-identity-regexp "https://github.com/teerakarna/helm-charts/.github/workflows/release.yml@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  kube-bench-0.1.0.tgz
```

### Verify a Docker image

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/teerakarna/helm-charts/.github/workflows/build-.*@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/teerakarna/dbclient:latest
```

Replace `dbclient` with `scoutsuite` or `bombardier` as appropriate.

## Repository structure

```
{chart-name}/             # One directory per chart
  Chart.yaml
  values.yaml
  templates/
  tests/                  # helm-unittest test files
  docker/                 # Dockerfile (charts with custom images)
.github/workflows/
  ci.yml                  # PR: ct lint + helm unittest
  release.yml             # Push to main: chart-releaser
  build-*.yml             # Manual: build and push custom Docker images
ct.yaml                   # chart-testing config
artifacthub-repo.yml      # ArtifactHub metadata
```
