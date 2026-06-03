#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

UFBT_DIR="${UFBT_HOME:-${PWD}/.ufbt}"
mkdir -p "${UFBT_DIR}"
# Docker volume mount for .ufbt is root-owned until we fix permissions.
if [ ! -w "${UFBT_DIR}" ]; then
    sudo chown -R "$(id -u):$(id -g)" "${UFBT_DIR}"
fi

echo "Installing uFBT..."
# PEP 668 blocks user installs on Debian; a dev container is an isolated environment.
python3 -m pip install --break-system-packages --disable-pip-version-check --no-cache-dir --upgrade pip ufbt

echo "Downloading Flipper SDK (this may take a few minutes)..."
ufbt update

echo "Downloading ARM GCC toolchain..."
mkdir -p zig-out/bin
touch zig-out/bin/app.o
ufbt -s || true
rm -f zig-out/bin/app.o

echo "Environment ready:"
zig version
ufbt status
