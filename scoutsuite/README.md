# scoutsuite

Multi-cloud security auditing tool ([ScoutSuite](https://github.com/nccgroup/ScoutSuite) by NCC Group). Runs as a Kubernetes CronJob or one-off Job to audit AWS, GCP, Azure, and other cloud providers, writing an HTML report to a persistent volume.

## Prerequisites

ScoutSuite has no official published Docker image. Build your own using the included Dockerfile and the GitHub Actions build pipeline, then push it to a registry your cluster can pull from.

**Build the image:**

```bash
# Trigger the manual workflow in GitHub Actions:
# Actions → Build ScoutSuite Image → Run workflow → enter version → Run

# Or build locally:
docker build \
  --build-arg SCOUTSUITE_VERSION=5.14.0 \
  -t ghcr.io/YOUR_USERNAME/scoutsuite:5.14.0 \
  scoutsuite/docker/

docker push ghcr.io/YOUR_USERNAME/scoutsuite:5.14.0
```

## Install

```bash
helm repo add teerakarna https://teerakarna.github.io/helm-charts
helm repo update

helm install scout teerakarna/scoutsuite \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set provider=aws
```

## Uninstall

```bash
helm uninstall scout
```

## Usage examples

### AWS with IRSA (recommended)

IRSA eliminates the need for long-lived credentials. The pod authenticates using the Kubernetes service account token exchanged for an AWS IAM role.

```bash
# Create the IAM role with read-only permissions for ScoutSuite, then:
helm install scout teerakarna/scoutsuite \
  --set provider=aws \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::123456789012:role/scoutsuite-readonly
```

### AWS with access keys (fallback)

```bash
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=AKIA... \
  --from-literal=AWS_SECRET_ACCESS_KEY=...

helm install scout teerakarna/scoutsuite \
  --set provider=aws \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set auth.aws.mode=accessKeys \
  --set auth.aws.existingSecret=aws-credentials
```

### GCP with service account key

```bash
kubectl create secret generic gcp-key --from-file=key.json=/path/to/key.json

helm install scout teerakarna/scoutsuite \
  --set provider=gcp \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set auth.gcp.mode=serviceAccount \
  --set auth.gcp.existingSecret=gcp-key \
  --set auth.gcp.projectId=my-project-id
```

### Azure with Workload Identity (recommended)

```bash
helm install scout teerakarna/scoutsuite \
  --set provider=azure \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set auth.azure.mode=workloadIdentity \
  --set auth.azure.subscriptionIds={your-subscription-id}
```

### Run as a one-off Job instead of a CronJob

```bash
helm install scout teerakarna/scoutsuite \
  --set workloadType=job \
  --set provider=aws \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite

# Watch until complete:
kubectl wait --for=condition=complete job -l app.kubernetes.io/instance=scout --timeout=30m

# View the report (exec into a debug pod with the PVC mounted):
helm install debug teerakarna/sleep --set persistence.enabled=false
kubectl cp debug-pod:/reports ./reports
```

### Scope to specific services and regions

```bash
helm install scout teerakarna/scoutsuite \
  --set provider=aws \
  --set image.repository=ghcr.io/YOUR_USERNAME/scoutsuite \
  --set "scout.services={iam,s3,ec2}" \
  --set "scout.regions={eu-central-1,eu-west-1}"
```

## Security notes

| What | Where | Never |
|---|---|---|
| AWS IRSA role ARN | `serviceAccount.annotations` | credentials in values |
| AWS access key ID + secret | `auth.aws.existingSecret` (Secret) | plain values |
| GCP service account JSON | `auth.gcp.existingSecret` (Secret, file mount) | plain values |
| Azure client secret | `auth.azure.existingSecret` (Secret) | plain values |

Azure service principal credentials are referenced as `$(ENV_VAR)` in container args — the actual values are not visible in the pod spec but are visible to the running process. Use Workload Identity (`auth.azure.mode: workloadIdentity`) to avoid this entirely.

`backoffLimit: 0` and `concurrencyPolicy: Forbid` are set by default. A failed scan should not silently retry or overlap with a running scan.

## Values

| Key | Default | Description |
|---|---|---|
| `provider` | `aws` | Cloud provider: `aws` \| `gcp` \| `azure` \| `aliyun` \| `oci` \| `kubernetes` \| `do` |
| `workloadType` | `cronjob` | `cronjob` \| `job` |
| `schedule` | `"0 2 * * *"` | CronJob schedule |
| `concurrencyPolicy` | `Forbid` | Prevent overlapping scans |
| `backoffLimit` | `0` | Do not retry failed scans |
| `activeDeadlineSeconds` | `0` | Job timeout (0 = none) |
| `image.repository` | `ghcr.io/teerakarna/scoutsuite` | Image — must be built first |
| `image.tag` | `"5.14.0"` | ScoutSuite version |
| `serviceAccount.annotations` | `{}` | Use for IRSA / Workload Identity annotation |
| `auth.aws.mode` | `irsa` | `irsa` \| `accessKeys` |
| `auth.aws.existingSecret` | `""` | Secret with AWS credentials (accessKeys mode) |
| `auth.gcp.mode` | `serviceAccount` | `workloadIdentity` \| `serviceAccount` |
| `auth.gcp.existingSecret` | `""` | Secret containing `key.json` |
| `auth.gcp.projectId` | `""` | GCP project ID |
| `auth.azure.mode` | `workloadIdentity` | `workloadIdentity` \| `servicePrincipal` |
| `auth.azure.existingSecret` | `""` | Secret with Azure SP credentials |
| `auth.azure.subscriptionIds` | `[]` | Azure subscription IDs to scan |
| `scout.services` | `[]` | Services to scan (default: all) |
| `scout.skip` | `[]` | Services to skip |
| `scout.regions` | `[]` | AWS regions to scan (default: all) |
| `scout.maxWorkers` | `10` | Concurrent API request threads |
| `scout.maxRate` | `null` | Max API requests/second |
| `scout.ruleset` | `default.json` | Analysis ruleset |
| `scout.resultFormat` | `json` | `json` \| `sqlite` |
| `output.reportDir` | `/reports` | Report output directory (inside container) |
| `output.reportName` | `""` | Report name (auto-generated if empty) |
| `persistence.enabled` | `true` | Create a PVC for the report |
| `persistence.size` | `1Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `resources.limits.cpu` | `"1"` | CPU limit |
| `resources.limits.memory` | `512Mi` | Memory limit |
