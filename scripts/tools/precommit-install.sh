#!/usr/bin/env bash
# Installs pre-commit (https://pre-commit.com) on Linux or macOS, then installs
# the git hook for this repo's .pre-commit-config.yaml.
# Uses Homebrew on macOS when available, otherwise pipx, otherwise pip --user.
# Override the version with PRE_COMMIT_VERSION=X.Y.Z (default set in versions.sh;
# Homebrew is only used for "latest").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../versions.sh"
VERSION="$PRE_COMMIT_VERSION"

case "$(uname -s)" in
  Linux | Darwin) ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  PKG="pre-commit"
else
  PKG="pre-commit==${VERSION}"
fi

if command -v pre-commit >/dev/null 2>&1; then
  echo "pre-commit already installed: $(pre-commit --version)"
elif [ "$(uname -s)" = "Darwin" ] && [ "$VERSION" = "latest" ] && command -v brew >/dev/null 2>&1; then
  brew install pre-commit
elif command -v pipx >/dev/null 2>&1; then
  pipx install "$PKG"
elif command -v python3 >/dev/null 2>&1; then
  # --break-system-packages is needed on distros that mark the system Python
  # as externally managed (PEP 668); it only affects the user site-packages.
  python3 -m pip install --user "$PKG" ||
    python3 -m pip install --user --break-system-packages "$PKG"
  export PATH="$(python3 -m site --user-base)/bin:$PATH"
else
  echo "Need Homebrew (macOS), pipx, or python3 to install pre-commit." >&2
  exit 1
fi

if ! command -v pre-commit >/dev/null 2>&1; then
  echo "pre-commit installed but not on PATH. Add your pipx/pip user bin directory" >&2
  echo "(usually ~/.local/bin) to PATH and rerun." >&2
  exit 1
fi

pre-commit --version

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "${REPO_ROOT}/.pre-commit-config.yaml" ]; then
  (cd "$REPO_ROOT" && pre-commit install)
fi
