#!/bin/bash
set -euo pipefail

# Installs kind (Kubernetes IN Docker) on macOS Apple Silicon (arm64).
# Override with KIND_VERSION=vX.Y.Z (only used for the binary fallback).
source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  echo "This script is for macOS on Apple Silicon (arm64)." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: docker not found. kind needs Docker Desktop (or colima/OrbStack) to create clusters." >&2
fi

if command -v brew >/dev/null 2>&1; then
  brew install kind
else
  TMP="$(mktemp)"
  trap 'rm -f "$TMP"' EXIT
  curl -fsSLo "$TMP" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-darwin-arm64"
  chmod +x "$TMP"
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
  if [ -w "$INSTALL_DIR" ]; then
    mv "$TMP" "$INSTALL_DIR/kind"
  else
    sudo mv "$TMP" "$INSTALL_DIR/kind"
  fi
fi

kind version
