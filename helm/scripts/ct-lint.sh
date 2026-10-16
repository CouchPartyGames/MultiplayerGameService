#!/usr/bin/env bash
# Runs `ct lint` with ct.yaml using the locally installed chart-testing CLI.
# With no arguments, lints charts under helm/charts/ changed against main; extra
# arguments go to ct (for example --all). The ct-lint pre-commit hook runs it.
set -euo pipefail

for BIN in ct helm yamllint yamale; do
  if ! command -v "$BIN" >/dev/null 2>&1; then
    case "$BIN" in
      helm) HINT="helm/scripts/helm-install.sh" ;;
      *) HINT="helm/tools/ct-install.sh" ;;
    esac
    echo "${BIN} not found; install it with ${HINT}" >&2
    exit 1
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

exec ct lint --config ct.yaml "$@"
