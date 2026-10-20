#!/bin/bash
set -euo pipefail

# k3s only runs on Linux, so on macOS this installs k3d, which runs k3s inside
# Docker, and creates a k3s cluster. Requires Docker Desktop (or colima/OrbStack).
# Override with K3S_VERSION=vX.Y.Z-k3s1 (default: k3d's bundled k3s) and
# K3D_CLUSTER_NAME=name (default: k3s-local).
source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
CLUSTER_NAME="${K3D_CLUSTER_NAME:-k3s-local}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS. Use k3s-install-linux.sh on Linux." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. k3d needs Docker Desktop (or colima/OrbStack)." >&2
  exit 1
fi

if ! command -v k3d >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install k3d
  else
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  fi
fi

k3d version

if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "k3d cluster '$CLUSTER_NAME' already exists"
else
  ARGS=()
  if [ -n "$K3S_VERSION" ]; then
    # k3d image tags use '-' where k3s release names use '+'.
    ARGS+=(--image "rancher/k3s:${K3S_VERSION//+/-}")
  fi
  k3d cluster create "$CLUSTER_NAME" --wait ${ARGS[@]+"${ARGS[@]}"}
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" 2>/dev/null || true
kubectl get nodes 2>/dev/null || echo "Install kubectl to interact with the cluster."
