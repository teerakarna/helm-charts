ARG ALPINE_VERSION=3.21

FROM alpine:${ALPINE_VERSION}

ARG ALPINE_VERSION

LABEL org.opencontainers.image.title="dbclient" \
      org.opencontainers.image.description="Database client debug pod — psql, redis-cli, and mysql in one Alpine container" \
      org.opencontainers.image.source="https://github.com/teerakarna/helm-charts"

# postgresql16-client: psql, pg_dump, pg_restore, pg_isready
# redis: redis-cli
# mariadb-client: mysql, mysqldump
# curl, jq: HTTP and JSON utilities for in-cluster debugging
RUN apk add --no-cache \
      postgresql16-client \
      redis \
      mariadb-client \
      curl \
      jq \
      bash \
    && rm -rf /var/cache/apk/*

RUN adduser -D -u 1000 -s /bin/bash dbclient

USER dbclient
WORKDIR /home/dbclient

CMD ["bash"]
