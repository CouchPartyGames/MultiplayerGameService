#!/bin/bash
set -euo pipefail

# Installs minikube on Linux. Override with MINIKUBE_VERSION=vX.Y.Z (default: latest)
source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: docker not found. scripts/minikube.sh uses --driver docker." >&2
fi

if [ "$MINIKUBE_VERSION" = "latest" ]; then
  URL="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}"
else
  URL="https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-${ARCH}"
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSLo "$TMP" "$URL"

if [ -w "$INSTALL_DIR" ]; then
  install -m 0755 "$TMP" "$INSTALL_DIR/minikube"
else
  sudo install -m 0755 "$TMP" "$INSTALL_DIR/minikube"
fi

minikube version
