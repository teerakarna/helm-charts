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

## Usage

```bash
# Install echoserver
helm install echo teerakarna/echoserver

# Port-forward and send a test request
kubectl port-forward svc/echo-echoserver 8080:80
curl http://localhost:8080/

# With ingress (nginx example)
helm install echo teerakarna/echoserver \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=echo.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"
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
```

### Run unit tests

```bash
helm unittest echoserver
```

### Render templates locally

```bash
helm template my-release echoserver
helm template my-release echoserver --set ingress.enabled=true
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
