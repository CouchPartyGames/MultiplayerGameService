#!/usr/bin/env bash
# Installs the ArgoCD CLI on macOS. Uses Homebrew when available, otherwise
# downloads the official GitHub release binary.
# Override the version with ARGOCD_CLI_VERSION=vX.Y.Z (default set in versions.sh).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
VERSION="$ARGOCD_CLI_VERSION"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

if command -v brew >/dev/null 2>&1 && [ "$VERSION" = "latest" ]; then
  brew install argocd
  argocd version --client
  exit 0
fi

case "$(uname -m)" in
  x86_64 | amd64) ARCH=amd64 ;;
  arm64 | aarch64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-${ARCH}"
else
  URL="https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-darwin-${ARCH}"
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "Downloading ${URL}"
curl -fsSL -o "$TMP" "$URL"

SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
  SUDO="sudo"
fi
$SUDO mkdir -p "$INSTALL_DIR"
$SUDO install -m 0755 "$TMP" "${INSTALL_DIR}/argocd"

echo "Installed to ${INSTALL_DIR}/argocd"
argocd version --client
