#!/usr/bin/env bash
set -euo pipefail

# Install TFLint on macOS or Linux. Override TFLINT_VERSION or INSTALL_DIR as needed.
source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

case "$(uname -s)" in
  Darwin) OS="darwin"; SHA256=(shasum -a 256) ;;
  Linux) OS="linux"; SHA256=(sha256sum) ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="tflint_${OS}_${ARCH}.zip"
BASE_URL="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}"
curl -fsSLo "$TMP_DIR/$ARCHIVE" "$BASE_URL/$ARCHIVE"
curl -fsSLo "$TMP_DIR/checksums.txt" "$BASE_URL/checksums.txt"

(
  cd "$TMP_DIR"
  awk -v archive="$ARCHIVE" '$2 == archive { print; found = 1 } END { if (!found) exit 1 }' checksums.txt | "${SHA256[@]}" -c -
)

unzip -p "$TMP_DIR/$ARCHIVE" tflint > "$TMP_DIR/tflint"
if [ -w "$INSTALL_DIR" ]; then
  install -m 0755 "$TMP_DIR/tflint" "$INSTALL_DIR/tflint"
else
  sudo install -m 0755 "$TMP_DIR/tflint" "$INSTALL_DIR/tflint"
fi

"$INSTALL_DIR/tflint" --version
