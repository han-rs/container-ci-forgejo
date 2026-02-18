# Simple wrapper over forgejo

# Base image
ARG ALPINE_BASE_VERSION=3.23.3
ARG ALPINE_BASE_HASH=25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

# Image METADATA
ARG IMAGE_BUILD_DATE=1970-01-01T00:00:00+00:00
ARG IMAGE_VCS_REF=00000000

# Versions
# These versions should be kept in sync with the ones in .github/workflows/ci.yaml.
ARG FORGEJO_VERSION=14.0.2

# Non-root user and group IDs
ARG UID=65532
ARG GID=65532

# Proxy settings
ARG http_proxy=""
ARG https_proxy=""

# === Download Stage ===

FROM alpine:${ALPINE_BASE_VERSION}@sha256:${ALPINE_BASE_HASH} AS downloader

ARG http_proxy
ARG https_proxy

RUN set -e && \
    apk -U upgrade && apk add --no-cache \
    ca-certificates=20251003-r0 \
    wget=1.25.0-r2

ARG TARGETARCH=amd64

ARG FORGEJO_VERSION

WORKDIR /opt/forgejo

RUN set -e \
    && \
    case ${TARGETARCH} in \
    "amd64")  FORGEJO_ARCH="amd64" \
    ;; \
    "arm64")  FORGEJO_ARCH="arm64" \
    ;; \
    *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1; \
    esac \
    && \
    wget -O ./forgejo "https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}/forgejo-${FORGEJO_VERSION}-linux-${FORGEJO_ARCH}"

# === Package Stage ===

FROM alpine:${ALPINE_BASE_VERSION}@sha256:${ALPINE_BASE_HASH}

ARG IMAGE_BUILD_DATE
ARG IMAGE_VCS_REF

ARG FORGEJO_VERSION

ARG UID
ARG GID

# OCI labels for image metadata
LABEL description="Third-party Forgejo Docker image" \
    org.opencontainers.image.created=${IMAGE_BUILD_DATE} \
    org.opencontainers.image.authors="Hantong Chen <public-service@7rs.net>" \
    org.opencontainers.image.url="https://github.com/han-rs/container-ci-forgejo" \
    org.opencontainers.image.documentation="https://github.com/han-rs/container-ci-forgejo/blob/main/README.md" \
    org.opencontainers.image.source="https://github.com/han-rs/container-ci-forgejo" \
    org.opencontainers.image.version=${FORGEJO_VERSION}+image.${IMAGE_VCS_REF} \
    org.opencontainers.image.vendor="Hantong Chen" \
    org.opencontainers.image.licenses="GPL-3.0-or-later" \
    org.opencontainers.image.title="Forgejo" \
    org.opencontainers.image.description="Third-party Forgejo Docker image"

RUN set -e && \
    apk -U upgrade && apk add --no-cache \
    bash=5.3.3-r1 \
    ca-certificates=20251003-r0 \
    git=2.52.0-r0 \
    gnupg=2.4.9-r0 \
    openssh-client=10.2_p1-r0

RUN set -e \
    && \
    addgroup -g "$GID" git \
    && \
    adduser -S -H -D -h /opt/forgejo/git -s /bin/bash -u "$UID" -G git git

COPY --from=downloader --chown="${UID}:${GID}" --chmod=775 /opt/forgejo /opt/forgejo

WORKDIR /opt/forgejo

# Run as non-root user.
USER "${UID}:${GID}"

# Prepare the data directory for forgejo.
RUN set -e \
    && \
    mkdir -p /opt/forgejo/custom \
    && \
    chmod 775 /opt/forgejo/custom \
    && \
    mkdir -p /opt/forgejo/data \
    && \
    chmod 775 /opt/forgejo/data

ENTRYPOINT ["/opt/forgejo/forgejo"]
