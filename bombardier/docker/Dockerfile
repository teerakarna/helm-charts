ARG BOMBARDIER_VERSION=1.2.6
ARG ALPINE_VERSION=3.21

# Download the pre-built bombardier binary for the target platform.
# TARGETARCH is set automatically by docker buildx (amd64 or arm64).
FROM alpine:${ALPINE_VERSION} AS downloader
ARG BOMBARDIER_VERSION
ARG TARGETARCH

RUN apk add --no-cache curl ca-certificates \
    && curl -fsSL \
         "https://github.com/codesenberg/bombardier/releases/download/v${BOMBARDIER_VERSION}/bombardier-linux-${TARGETARCH}" \
         -o /usr/local/bin/bombardier \
    && chmod +x /usr/local/bin/bombardier

FROM alpine:${ALPINE_VERSION}
ARG BOMBARDIER_VERSION

LABEL org.opencontainers.image.title="bombardier" \
      org.opencontainers.image.description="Fast cross-platform HTTP/S benchmarking tool" \
      org.opencontainers.image.version="${BOMBARDIER_VERSION}" \
      org.opencontainers.image.source="https://github.com/teerakarna/helm-charts"

RUN apk add --no-cache ca-certificates \
    && adduser -D -u 1000 -s /bin/sh bombardier

COPY --from=downloader /usr/local/bin/bombardier /usr/local/bin/bombardier

USER bombardier

ENTRYPOINT ["bombardier"]
CMD ["--help"]
