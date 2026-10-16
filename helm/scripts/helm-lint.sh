#!/usr/bin/env bash
# Runs `helm lint --strict` on each chart under helm/charts/ that contains one of
# the given files. pre-commit passes the changed files; with no arguments, every
# chart under helm/charts/ is linted.
set -euo pipefail

if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found; install it with helm/scripts/helm-install.sh" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ "$#" -eq 0 ]; then
  set -- helm/charts/*/Chart.yaml
fi

# Walk up from each file to the nearest directory with a Chart.yaml.
declare -A CHARTS=()
for file in "$@"; do
  dir="$(dirname "$file")"
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    if [ -f "${dir}/Chart.yaml" ]; then
      CHARTS["$dir"]=1
      break
    fi
    dir="$(dirname "$dir")"
  done
done

status=0
for chart in "${!CHARTS[@]}"; do
  helm lint --strict "$chart" || status=1
done
exit "$status"
