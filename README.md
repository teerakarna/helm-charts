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
| [scoutsuite](./scoutsuite/) | Multi-cloud security auditing (ScoutSuite) — CronJob/Job for AWS, GCP, Azure and more | 0.1.0 |
| [gonymizer](./gonymizer/) | PostgreSQL data anonymization (Gonymizer) — dump, anonymize, and reload PII/PHI for QA | 0.1.0 |

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
ct lint --config ct.yaml --charts echoserver
ct lint --config ct.yaml --charts netshoot
ct lint --config ct.yaml --charts sleep
```

### Run unit tests

```bash
helm unittest echoserver
helm unittest netshoot
helm unittest sleep
```

### Render templates locally

```bash
helm template my-release echoserver
helm template my-release netshoot
helm template my-release sleep
```

## Releasing

Charts are released automatically on merge to `main` via [chart-releaser-action](https://github.com/helm/chart-releaser-action).

To release a new chart version:
1. Bump `version` in the chart's `Chart.yaml`
2. Open a PR — CI lints and runs unit tests
3. Merge to `main` — chart-releaser packages the chart, creates a GitHub Release, and updates the Helm repository index on the `gh-pages` branch

> **First-time setup:** After the first release workflow runs and creates the `gh-pages` branch, enable GitHub Pages in the repo settings pointing to that branch.

## Repository structure

```
{chart-name}/             # One directory per chart
  Chart.yaml
  values.yaml
  templates/
  tests/                  # helm-unittest test files
.github/workflows/
  ci.yml                  # PR: ct lint + helm unittest
  release.yml             # Push to main: chart-releaser
ct.yaml                   # chart-testing config
artifacthub-repo.yml      # ArtifactHub metadata
```
