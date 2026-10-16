#!/usr/bin/env bash
# Installs the Helm CLI on Linux or macOS from the official release tarball
# at get.helm.sh, verifying its SHA-256 checksum.
# Override the version with HELM_VERSION=vX.Y.Z (default set in version.sh;
# "latest" resolves to the newest release).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
VERSION="$HELM_VERSION"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -s)" in
  Linux) OS=linux ;;
  Darwin) OS=darwin ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  VERSION="$(curl -fsSL https://get.helm.sh/helm-latest-version)"
fi
case "$VERSION" in
  v*) ;;
  *) VERSION="v${VERSION}" ;;
esac

TARBALL="helm-${VERSION}-${OS}-${ARCH}.tar.gz"
URL="https://get.helm.sh/${TARBALL}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${URL}"
curl -fsSL -o "${TMP_DIR}/${TARBALL}" "$URL"
curl -fsSL -o "${TMP_DIR}/${TARBALL}.sha256sum" "${URL}.sha256sum"

EXPECTED="$(awk '{print $1}' "${TMP_DIR}/${TARBALL}.sha256sum")"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "${TMP_DIR}/${TARBALL}" | awk '{print $1}')"
else
  ACTUAL="$(shasum -a 256 "${TMP_DIR}/${TARBALL}" | awk '{print $1}')"
fi
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "Checksum mismatch for ${TARBALL}: expected ${EXPECTED}, got ${ACTUAL}" >&2
  exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR"

SUDO=""
mkdir -p "$INSTALL_DIR" 2>/dev/null || true
if [ ! -w "$INSTALL_DIR" ]; then
  SUDO="sudo"
fi
$SUDO mkdir -p "$INSTALL_DIR"
$SUDO install -m 0755 "${TMP_DIR}/${OS}-${ARCH}/helm" "${INSTALL_DIR}/helm"

echo "Installed to ${INSTALL_DIR}/helm"
"${INSTALL_DIR}/helm" version
