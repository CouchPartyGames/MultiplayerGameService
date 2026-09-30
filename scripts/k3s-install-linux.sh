#!/bin/bash
set -euo pipefail

# Installs k3s (single-node Kubernetes) on Linux using the official installer.
# Override with K3S_VERSION=vX.Y.Z+k3s1 (default: stable channel).
# Extra server flags can be passed with INSTALL_K3S_EXEC, e.g. "--disable traefik".
source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This script is for Linux. Use k3s-install-mac.sh on macOS." >&2
  exit 1
fi

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed: $(k3s --version | head -n1)"
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# Make the kubeconfig readable so kubectl/helm work without sudo.
export INSTALL_K3S_VERSION="${K3S_VERSION}"
export INSTALL_K3S_EXEC="${INSTALL_K3S_EXEC:---write-kubeconfig-mode 644}"

curl -sfL https://get.k3s.io | $SUDO -E sh -

echo "Waiting for node to be Ready..."
$SUDO k3s kubectl wait --for=condition=Ready node --all --timeout=180s

k3s --version | head -n1
echo
echo "Kubeconfig: /etc/rancher/k3s/k3s.yaml"
echo "Use it with: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
