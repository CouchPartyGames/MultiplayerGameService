#!/bin/bash
set -euo pipefail

# Installs kind (Kubernetes IN Docker) on Linux. Override with KIND_VERSION=vX.Y.Z
KIND_VERSION="${KIND_VERSION:-v0.27.0}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: docker not found. kind needs Docker (or podman) to create clusters." >&2
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSLo "$TMP" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
chmod +x "$TMP"

if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP" "$INSTALL_DIR/kind"
else
  sudo mv "$TMP" "$INSTALL_DIR/kind"
fi

kind version
