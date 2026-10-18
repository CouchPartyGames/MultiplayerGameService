#!/usr/bin/env bash
# Installs yamlfmt (https://github.com/google/yamlfmt) on Linux or macOS for the
# current user from the official GitHub release, verifying its SHA-256 checksum.
# No sudo: installs to ~/.local/bin unless INSTALL_DIR is set.
# Override the version with YAMLFMT_VERSION=vX.Y.Z (default: latest).
set -euo pipefail

VERSION="${YAMLFMT_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
REPO_URL="https://github.com/google/yamlfmt"

case "$(uname -s)" in
  Linux) OS=Linux ;;
  Darwin) OS=Darwin ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) ARCH=x86_64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  # releases/latest redirects to releases/tag/vX.Y.Z
  VERSION="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${REPO_URL}/releases/latest")"
  VERSION="${VERSION##*/}"
fi
case "$VERSION" in
  v*) ;;
  *) VERSION="v${VERSION}" ;;
esac

ARCHIVE="yamlfmt_${VERSION#v}_${OS}_${ARCH}.tar.gz"
BASE_URL="${REPO_URL}/releases/download/${VERSION}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${BASE_URL}/${ARCHIVE}"
curl -fsSL -o "${TMP}/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}"
curl -fsSL -o "${TMP}/checksums.txt" "${BASE_URL}/checksums.txt"

if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
else
  SHA_CMD="shasum -a 256"
fi
(cd "$TMP" && grep " ${ARCHIVE}\$" checksums.txt | $SHA_CMD -c -)

tar -xzf "${TMP}/${ARCHIVE}" -C "$TMP" yamlfmt
mkdir -p "$INSTALL_DIR"
install -m 0755 "${TMP}/yamlfmt" "${INSTALL_DIR}/yamlfmt"

echo "Installed to ${INSTALL_DIR}/yamlfmt"
"${INSTALL_DIR}/yamlfmt" -version

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *) echo "Note: ${INSTALL_DIR} is not on PATH. Add it to your shell profile." >&2 ;;
esac
