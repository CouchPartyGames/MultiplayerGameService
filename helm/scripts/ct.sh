#!/usr/bin/env bash
# Runs chart-testing (ct) from its Docker image against ct.yaml, so ct, yamllint,
# and yamale need not be installed locally. Extra arguments go to ct.
#
#   helm/scripts/ct.sh lint             # charts changed against main
#   helm/scripts/ct.sh lint --all
#   helm/scripts/ct.sh install          # into the current kube context
#
# `install` creates a namespace per chart in the current kube context and deletes
# it afterwards. Point the context at a local cluster (minikube, kind, k3s) first.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <lint|install|list-changed> [ct args...]" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found; it is needed to run the chart-testing image" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=helm/scripts/version.sh
source "${REPO_ROOT}/helm/scripts/version.sh"

# Mount the repo at its own path and run as the current user so git sees the
# same checkout. safe.directory covers images whose git rejects the mount owner.
DOCKER_ARGS=(
  --rm
  --user "$(id -u):$(id -g)"
  --volume "${REPO_ROOT}:${REPO_ROOT}"
  --workdir "${REPO_ROOT}"
  --env HOME=/tmp
  --env GIT_CONFIG_COUNT=1
  --env GIT_CONFIG_KEY_0=safe.directory
  --env "GIT_CONFIG_VALUE_0=${REPO_ROOT}"
)

if [ "$1" = "install" ]; then
  KUBECONFIG_FILE="${KUBECONFIG:-${HOME}/.kube/config}"
  if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "kubeconfig not found at ${KUBECONFIG_FILE}; start a local cluster first" >&2
    exit 1
  fi
  # Host networking reaches clusters on localhost (kind, k3d); minikube's
  # kubeconfig points at certificate files under ~/.minikube.
  DOCKER_ARGS+=(
    --network host
    --volume "${KUBECONFIG_FILE}:/tmp/kubeconfig:ro"
    --env KUBECONFIG=/tmp/kubeconfig
  )
  if [ -d "${HOME}/.minikube" ]; then
    DOCKER_ARGS+=(--volume "${HOME}/.minikube:${HOME}/.minikube:ro")
  fi
fi

exec docker run "${DOCKER_ARGS[@]}" "quay.io/helmpack/chart-testing:${CT_VERSION}" \
  ct "$@" --config ct.yaml
