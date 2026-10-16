#!/usr/bin/env bash
# Installs chart-testing (ct, https://github.com/helm/chart-testing) on Linux or
# macOS from the official GitHub release, verifying its SHA-256 checksum, for
# helm/scripts/ct-lint.sh and ct-test.sh.
#
# Installs:
#   - ct to INSTALL_DIR (default: /usr/local/bin; sudo only if not writable)
#   - chart_schema.yaml and lintconf.yaml to ~/.ct, where ct looks for them
#   - yamllint and yamale, which `ct lint` calls, if missing (pipx, else pip --user)
#
# Override the version with CT_VERSION=vX.Y.Z (default set in
# helm/scripts/version.sh, shared with CI; the leading "v" is optional).
# ct also needs helm and, for `ct install`, kubectl on PATH.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/version.sh"
VERSION="${CT_VERSION#v}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${HOME}/.ct"

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

TARBALL="chart-testing_${VERSION}_${OS}_${ARCH}.tar.gz"
BASE_URL="https://github.com/helm/chart-testing/releases/download/v${VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${BASE_URL}/${TARBALL}"
curl -fsSL -o "${TMP_DIR}/${TARBALL}" "${BASE_URL}/${TARBALL}"
curl -fsSL -o "${TMP_DIR}/checksums.txt" "${BASE_URL}/checksums.txt"

EXPECTED="$(awk -v f="$TARBALL" '$2 == f {print $1}' "${TMP_DIR}/checksums.txt")"
if [ -z "$EXPECTED" ]; then
  echo "No checksum for ${TARBALL} in checksums.txt" >&2
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

tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR"

SUDO=""
mkdir -p "$INSTALL_DIR" 2>/dev/null || true
if [ ! -w "$INSTALL_DIR" ]; then
  SUDO="sudo"
fi
$SUDO mkdir -p "$INSTALL_DIR"
$SUDO install -m 0755 "${TMP_DIR}/ct" "${INSTALL_DIR}/ct"
echo "Installed to ${INSTALL_DIR}/ct"

mkdir -p "$CONFIG_DIR"
install -m 0644 "${TMP_DIR}/etc/chart_schema.yaml" "${TMP_DIR}/etc/lintconf.yaml" "$CONFIG_DIR/"
echo "Installed lint config to ${CONFIG_DIR}"

# ct lint shells out to yamllint and yamale.
for PKG in yamllint yamale; do
  if command -v "$PKG" >/dev/null 2>&1; then
    echo "${PKG} already installed"
  elif command -v pipx >/dev/null 2>&1; then
    pipx install "$PKG"
  elif command -v python3 >/dev/null 2>&1; then
    # --break-system-packages is needed on distros that mark the system Python
    # as externally managed (PEP 668); it only affects the user site-packages.
    python3 -m pip install --user "$PKG" ||
      python3 -m pip install --user --break-system-packages "$PKG"
  else
    echo "Need pipx or python3 to install ${PKG}, which ct lint requires." >&2
    exit 1
  fi
done

for BIN in yamllint yamale; do
  if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "${BIN} installed but not on PATH. Add your pipx/pip user bin directory" >&2
    echo "(usually ~/.local/bin) to PATH." >&2
  fi
done

"${INSTALL_DIR}/ct" version
