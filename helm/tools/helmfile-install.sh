#!/usr/bin/env bash
# Installs helmfile (https://github.com/helmfile/helmfile) on Linux or macOS
# from the official GitHub release, verifying its SHA-256 checksum.
#
# Installs helmfile to INSTALL_DIR (default: ~/.local/bin on Linux,
# /usr/local/bin on macOS; sudo only if not writable).
#
# Override the version with HELMFILE_VERSION=vX.Y.Z (default set in
# helm/scripts/version.sh; the leading "v" is optional).
# helmfile also needs helm on PATH, plus the helm-diff plugin for
# `helmfile diff` and `helmfile apply` (run `helmfile init` to install it).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/version.sh"
VERSION="${HELMFILE_VERSION#v}"

case "$(uname -s)" in
  Linux) OS=linux; DEFAULT_INSTALL_DIR="${HOME}/.local/bin" ;;
  Darwin) OS=darwin; DEFAULT_INSTALL_DIR=/usr/local/bin ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

case "$(uname -m)" in
  x86_64 | amd64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

TARBALL="helmfile_${VERSION}_${OS}_${ARCH}.tar.gz"
CHECKSUMS="helmfile_${VERSION}_checksums.txt"
BASE_URL="https://github.com/helmfile/helmfile/releases/download/v${VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${BASE_URL}/${TARBALL}"
curl -fsSL -o "${TMP_DIR}/${TARBALL}" "${BASE_URL}/${TARBALL}"
curl -fsSL -o "${TMP_DIR}/${CHECKSUMS}" "${BASE_URL}/${CHECKSUMS}"

EXPECTED="$(awk -v f="$TARBALL" '$2 == f {print $1}' "${TMP_DIR}/${CHECKSUMS}")"
if [ -z "$EXPECTED" ]; then
  echo "No checksum for ${TARBALL} in ${CHECKSUMS}" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "${TMP_DIR}/${TARBALL}" | awk '{print $1}')"
else
  ACTUAL="$(shasum -a 256 "${TMP_DIR}/${TARBALL}" | awk '{print $1}')"
fi
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "Checksum mismatch for ${TARBALL}: expected ${EXPECTED}, got ${ACTUAL}" >&2
  exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR" helmfile

SUDO=""
mkdir -p "$INSTALL_DIR" 2>/dev/null || true
if [ ! -w "$INSTALL_DIR" ]; then
  SUDO="sudo"
fi
$SUDO mkdir -p "$INSTALL_DIR"
$SUDO install -m 0755 "${TMP_DIR}/helmfile" "${INSTALL_DIR}/helmfile"
echo "Installed to ${INSTALL_DIR}/helmfile"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *) echo "${INSTALL_DIR} is not on PATH. Add it to PATH to run helmfile." >&2 ;;
esac

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is not on PATH; helmfile needs it. Run helm/scripts/helm-install.sh." >&2
fi

"${INSTALL_DIR}/helmfile" --version
