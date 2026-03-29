# helm-charts

Helm chart repository hosted on GitHub Pages via chart-releaser. Each directory at the repo
root is an independent Helm chart. Charts are released automatically on merge to `main`.

## Repo layout

```
{chart-name}/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl       # name/fullname/labels/selectorLabels/serviceAccountName + chart-specific helpers
    NOTES.txt
    serviceaccount.yaml
    job.yaml           # Job/CronJob charts
    cronjob.yaml       # Job/CronJob charts
    pvc.yaml           # Job/CronJob charts with persistence
    rbac.yaml          # charts that need cluster access
    deployment.yaml    # Deployment charts
    service.yaml       # Deployment charts
    configmap.yaml     # charts with config/scripts
  tests/
    job_test.yaml      # helm-unittest test files
    cronjob_test.yaml
    deployment_test.yaml
  docker/              # only for charts with a custom image (no official image exists)
    Dockerfile
.github/
  dependabot.yml       # weekly Monday GitHub Actions updates
  workflows/
    ci.yml             # PR: ct lint + helm unittest + kubeconform
    release.yml        # push to main: chart-releaser + cosign signing
    build-{name}.yml   # manual: build + Trivy scan + push + cosign sign custom images
ct.yaml                # chart-testing config (charts-dir: .)
artifacthub-repo.yml
```

## Two chart patterns

### 1. Job/CronJob (security tools, batch workloads, load tests)

Used by: scoutsuite, kube-bench, kube-hunter, gonymizer, bombardier, trivy, k6

Key conventions:
- `workloadType: job | cronjob` — single values.yaml controls both
- `job.yaml` and `cronjob.yaml` both call `{{ include "CHART.podSpec" . }}`
- `podSpec` helper contains `restartPolicy: Never` and all shared pod config
- `automountServiceAccountToken: false` at pod spec level (override to `true` at pod spec
  level only when the chart genuinely needs API access, e.g. kube-bench, trivy k8s mode)
- `serviceaccount.yaml` always has `automountServiceAccountToken: false` at SA level
- `backoffLimit: 0` default — partial retries produce inconsistent results for audit tools
- PVC optional via `persistence.enabled`; `pvc.yaml` uses `{{- if and ... (not existingClaim) }}`
- `rbac.yaml` with `rbac.create` guard for charts needing ClusterRole (kube-bench, trivy)

### 2. Deployment (long-running services/proxies)

Used by: echoserver, netshoot, sleep, dbclient, toxiproxy

Key conventions:
- Standard Deployment + Service + optional ConfigMap
- `automountServiceAccountToken: false` directly on the Deployment pod spec
- `readOnlyRootFilesystem: true` where possible; document exceptions in values.yaml comments
- Config mounted from ConfigMap via `subPath` (toxiproxy pattern)
- Liveness/readiness probes defined in values.yaml (not hardcoded in deployment.yaml)

## Security baseline (all charts)

Every chart must have:
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000  # (or image-appropriate UID)
  runAsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # or false with explanation
  capabilities:
    drop:
      - ALL

automountServiceAccountToken: false  # at both SA and pod spec level
```

## _helpers.tpl structure

Every chart has the same six standard helpers:
1. `CHART.name` — trunc 63
2. `CHART.fullname` — release-name deduplication
3. `CHART.chart` — name-version for label
4. `CHART.labels` — helm.sh/chart + selectorLabels + version + managed-by
5. `CHART.selectorLabels` — name + instance
6. `CHART.serviceAccountName` — create/existing logic

Plus chart-specific helpers:
- `CHART.args` — builds the CLI args list (use `{{- include "CHART.args" . | trim | nindent 6 }}`)
- `CHART.podSpec` — shared pod spec for Job/CronJob charts
- `CHART.pvcName` — existingClaim fallback

Use `| trim | nindent N` on multi-line helper includes to prevent blank leading lines.

## CLI args pattern

Always build args as a YAML list (one flag per entry). This avoids shell quoting issues:
```yaml
- --flag
- {{ .Values.someValue | quote }}
```
Never: `- "--flag={{ .Values.someValue }}"` (breaks on values with spaces/special chars)

Target/URL is always the last arg (bombardier, trivy, k6 target is the script path).

## Custom Docker images

Three charts need custom images (no suitable official image):
- **scoutsuite**: `ghcr.io/teerakarna/scoutsuite` — built via `build-scoutsuite.yml`
- **dbclient**: `ghcr.io/teerakarna/dbclient` — built via `build-dbclient.yml`
- **bombardier**: `ghcr.io/teerakarna/bombardier` — built via `build-bombardier.yml`

Build workflow pattern:
1. Build amd64 locally (`load: true`) for Trivy scan
2. Trivy scan: `exit-code: "1"`, `ignore-unfixed: true`, HIGH/CRITICAL only
3. Build + push multi-arch (`linux/amd64,linux/arm64`) — GHA cache reuse makes this fast
4. `cosign sign --yes IMAGE@DIGEST` (keyless, OIDC)
5. `id-token: write` permission required on the job

## Release pipeline

On merge to `main`:
1. `chart-releaser-action@v1.7.0` packages new/changed charts, creates GitHub Releases,
   updates `gh-pages` index. `skip_existing: true`.
2. Sign chart packages: `cosign sign-blob --bundle PKG.bundle --yes PKG`
3. Upload `.bundle` files to the corresponding GitHub Release as assets.

Helm repo URL: `https://teerakarna.github.io/helm-charts`

## CI pipeline (PRs)

`.github/workflows/ci.yml` on PR to main:
1. `ct list-changed` — detect changed charts
2. `helm plugin install helm-unittest` (if changed)
3. Install kubeconform v0.6.7 (if changed)
4. `ct lint` — yamllint + helm lint
5. `helm unittest CHART` — per changed chart
6. `helm template | kubeconform --strict --ignore-missing-schemas --kubernetes-version 1.32.0`

## Testing (helm-unittest)

Test files in `{chart}/tests/`. Key patterns:
```yaml
suite: job
templates:
  - job.yaml
tests:
  - it: should not create a Job when workloadType=cronjob
    set:
      workloadType: cronjob
    asserts:
      - hasDocuments:
          count: 0
```

Multi-template tests (e.g. k6 job + configmap) use `template: job.yaml` per test to scope
assertions to a single document.

Always test:
- Correct resource kind created / absent for alternate workloadType
- Security context: `runAsNonRoot`, `allowPrivilegeEscalation`
- `automountServiceAccountToken` value
- Key CLI args present/absent based on values
- `restartPolicy: Never` for Job/CronJob
- Volume mounts when persistence/configmap is involved

## Supply chain security

All chart packages and Docker images are signed with keyless cosign (GitHub Actions OIDC).

Verify a chart package:
```bash
cosign verify-blob \
  --bundle CHART-VERSION.tgz.bundle \
  --certificate-identity-regexp "https://github.com/teerakarna/helm-charts/.github/workflows/release.yml@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  CHART-VERSION.tgz
```

Verify an image:
```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/teerakarna/helm-charts/.github/workflows/build-.*@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/teerakarna/IMAGE:TAG
```

## Adding a new chart — checklist

1. Create `{chart}/Chart.yaml` — apiVersion v2, version 0.1.0, appVersion matching upstream
2. Create `{chart}/values.yaml` — document every field with `# --` comments
3. Copy `_helpers.tpl` from nearest similar chart; replace all occurrences of old chart name
4. Write templates following the Job/CronJob or Deployment pattern above
5. Write `tests/` — minimum: kind assertion, security context, key arg flags, workloadType switch
6. Run locally: `helm unittest {chart}`, `ct lint --config ct.yaml --charts {chart}`,
   `helm template test-release {chart} | kubeconform --strict --ignore-missing-schemas --kubernetes-version 1.32.0 --summary`
7. If a custom Docker image is needed, add `docker/Dockerfile` + `.github/workflows/build-{chart}.yml`
   following the two-phase Trivy scan pattern
8. Add entry to README.md Available charts table and Usage section

## Branch protection

Main branch: required status check `lint-test`, no force pushes, no deletions.
`enforce_admins: false` — admin merges can bypass required checks (used for Dependabot PRs
where CI trivially passes since no charts change).

Secret scanning + push protection enabled.
