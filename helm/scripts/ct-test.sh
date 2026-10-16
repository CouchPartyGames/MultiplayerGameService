#!/usr/bin/env bash
# Runs `ct install` with ct.yaml using the locally installed chart-testing CLI:
# installs each chart under helm/charts/ changed against main into the current
# kube context, runs its `helm test` hooks, then deletes its namespace. Extra
# arguments go to ct (for example --all). The ct-install pre-commit hook runs it.
#
# Point the kube context at a local cluster (minikube, kind, k3s) first.
set -euo pipefail

for BIN in ct helm kubectl; do
  if ! command -v "$BIN" >/dev/null 2>&1; then
    case "$BIN" in
      ct) HINT="install it with helm/tools/ct-install.sh" ;;
      helm) HINT="install it with helm/scripts/helm-install.sh" ;;
      kubectl) HINT="install it from https://kubernetes.io/docs/tasks/tools/" ;;
    esac
    echo "${BIN} not found; ${HINT}" >&2
    exit 1
  fi
done

if ! CONTEXT="$(kubectl config current-context 2>/dev/null)"; then
  echo "No current kube context; start a local cluster first" >&2
  exit 1
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "Cluster for kube context ${CONTEXT} is unreachable; start it first" >&2
  exit 1
fi
echo "Installing charts into kube context: ${CONTEXT}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

exec ct install --config ct.yaml "$@"
