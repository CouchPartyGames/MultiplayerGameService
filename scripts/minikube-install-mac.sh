#!/bin/bash
set -euo pipefail

# Installs minikube on macOS Apple Silicon (arm64).
# Override with MINIKUBE_VERSION=vX.Y.Z (only used for the binary fallback, default: latest).
MINIKUBE_VERSION="${MINIKUBE_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  echo "This script is for macOS on Apple Silicon (arm64)." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: docker not found. scripts/minikube.sh uses --driver docker (Docker Desktop, colima, or OrbStack)." >&2
fi

if command -v brew >/dev/null 2>&1; then
  brew install minikube
else
  URL="https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-darwin-arm64"
  TMP="$(mktemp)"
  trap 'rm -f "$TMP"' EXIT
  curl -fsSLo "$TMP" "$URL"
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
  if [ -w "$INSTALL_DIR" ]; then
    install -m 0755 "$TMP" "$INSTALL_DIR/minikube"
  else
    sudo install -m 0755 "$TMP" "$INSTALL_DIR/minikube"
  fi
fi

minikube version
