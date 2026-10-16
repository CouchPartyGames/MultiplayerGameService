#!/usr/bin/env bash
set -euo pipefail

# Install Terraform on Linux. Override TERRAFORM_VERSION or INSTALL_DIR as needed.
source "$(dirname "${BASH_SOURCE[0]}")/version.sh"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This script is for Linux." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip"
BASE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
curl -fsSLo "$TMP_DIR/$ARCHIVE" "$BASE_URL/$ARCHIVE"
curl -fsSLo "$TMP_DIR/SHA256SUMS" "$BASE_URL/terraform_${TERRAFORM_VERSION}_SHA256SUMS"

(
  cd "$TMP_DIR"
  awk -v archive="$ARCHIVE" '$2 == archive { print; found = 1 } END { if (!found) exit 1 }' SHA256SUMS | sha256sum -c -
)

unzip -p "$TMP_DIR/$ARCHIVE" terraform > "$TMP_DIR/terraform"
if [ -w "$INSTALL_DIR" ]; then
  install -m 0755 "$TMP_DIR/terraform" "$INSTALL_DIR/terraform"
else
  sudo install -m 0755 "$TMP_DIR/terraform" "$INSTALL_DIR/terraform"
fi

"$INSTALL_DIR/terraform" version
