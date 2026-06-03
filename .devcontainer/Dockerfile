# Flipper Zero Zig template — development container with Zig and uFBT.
# See https://github.com/flipperdevices/flipperzero-ufbt

FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG ZIG_VERSION=0.15.1
ARG TARGETARCH

# Some devcontainer Python images ship a Yarn apt source that breaks apt-get update.
RUN rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true \
    && find /etc/apt/sources.list.d -name '*.list' -exec sed -i '/yarnpkg/d' {} + 2>/dev/null || true

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (host arch inside the container; see https://ziglang.org/download/)
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ZIG_ARCH=x86_64 ;; \
        arm64) ZIG_ARCH=aarch64 ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    ZIG_BUNDLE="zig-${ZIG_ARCH}-linux-${ZIG_VERSION}"; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_BUNDLE}.tar.xz" \
        | tar -xJ -C /usr/local; \
    mv "/usr/local/${ZIG_BUNDLE}" /usr/local/zig; \
    ln -sf /usr/local/zig/zig /usr/local/bin/zig
