#!/bin/bash
set -euo pipefail

if command -v minikube >/dev/null 2>&1; then
  echo "minikube is already installed."
  exit 0
fi

# Installs minikube on Linux. Override with MINIKUBE_VERSION=vX.Y.Z (default: latest)
source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac


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

whereis minikube
minikube version
