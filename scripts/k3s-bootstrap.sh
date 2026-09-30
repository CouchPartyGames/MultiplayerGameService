#!/usr/bin/env bash
set -euo pipefail

# Installs k3s if needed (k3d on macOS), then installs ArgoCD into it.
# Linux uses the k3s kubeconfig (override with KUBECONFIG); macOS uses the
# k3d-${K3D_CLUSTER_NAME} context.
DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$DIR/versions.sh"

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required to install ArgoCD." >&2
  exit 1
fi

HELM_ARGS=()
case "$(uname -s)" in
  Linux)
    if ! command -v k3s >/dev/null 2>&1; then
      "$DIR/k3s-install-linux.sh"
    fi
    export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
    ;;
  Darwin)
    CLUSTER="${K3D_CLUSTER_NAME:-k3s-local}"
    # The mac installer is idempotent: it creates the cluster only if missing.
    "$DIR/k3s-install-mac.sh"
    HELM_ARGS+=(--kube-context "k3d-${CLUSTER}")
    ;;
  *)
    echo "Unsupported platform: $(uname -s)" >&2
    exit 1
    ;;
esac

helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  ${HELM_ARGS[@]+"${HELM_ARGS[@]}"} \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --wait
