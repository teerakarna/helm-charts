# ScoutSuite — Multi-cloud security auditing tool
# https://github.com/nccgroup/ScoutSuite
#
# Build:
#   docker build --build-arg SCOUTSUITE_VERSION=5.14.0 -t scoutsuite:5.14.0 .
#
# Run (AWS with IRSA / instance profile — no credentials needed):
#   docker run --rm -v $(pwd)/reports:/reports scoutsuite:5.14.0 \
#     aws --no-browser --report-dir /reports
#
# Run (AWS with access keys):
#   docker run --rm \
#     -e AWS_ACCESS_KEY_ID=... \
#     -e AWS_SECRET_ACCESS_KEY=... \
#     -v $(pwd)/reports:/reports \
#     scoutsuite:5.14.0 aws --no-browser --report-dir /reports
#
# The image is intentionally provider-agnostic — all providers supported by
# ScoutSuite are available. Provider-specific cloud CLI tools (aws-cli, gcloud,
# az) are NOT included; authenticate via credentials/IRSA/Workload Identity instead.

ARG SCOUTSUITE_VERSION=5.14.0
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS builder

ARG SCOUTSUITE_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && pip install --no-cache-dir --prefix=/install scoutsuite==${SCOUTSUITE_VERSION} \
    && apt-get purge -y --auto-remove gcc \
    && rm -rf /var/lib/apt/lists/*


FROM python:${PYTHON_VERSION}-slim

ARG SCOUTSUITE_VERSION

LABEL org.opencontainers.image.title="ScoutSuite" \
      org.opencontainers.image.description="Multi-cloud security auditing tool by NCC Group" \
      org.opencontainers.image.source="https://github.com/nccgroup/ScoutSuite" \
      org.opencontainers.image.version="${SCOUTSUITE_VERSION}" \
      org.opencontainers.image.licenses="GPL-2.0"

COPY --from=builder /install /usr/local

# Create non-root user
RUN useradd --create-home --uid 1000 --shell /bin/sh scout \
    && mkdir -p /reports \
    && chown scout:scout /reports

USER scout
WORKDIR /home/scout

ENTRYPOINT ["scout"]
CMD ["--help"]
