#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/version.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to install Terraform on macOS." >&2
  exit 1
fi

brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
