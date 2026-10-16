#!/usr/bin/env bash
# Installs the ArgoCD CLI on Linux from the official GitHub release.
# Override the version with ARGOCD_CLI_VERSION=vX.Y.Z (default set in versions.sh).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
VERSION="$ARGOCD_CLI_VERSION"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64 | amd64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
else
  URL="https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-${ARCH}"
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "Downloading ${URL}"
curl -fsSL -o "$TMP" "$URL"

SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
  SUDO="sudo"
fi
$SUDO install -m 0755 "$TMP" "${INSTALL_DIR}/argocd"

echo "Installed to ${INSTALL_DIR}/argocd"
argocd version --client
