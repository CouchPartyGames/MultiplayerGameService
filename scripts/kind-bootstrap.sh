#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

if ! command -v kind >/dev/null 2>&1; then
  echo "Error: kind is not installed or is not on PATH." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required to install ArgoCD." >&2
  exit 1
fi

CLUSTER="multiplayer-demo"

echo "Starting kind cluster '$CLUSTER'..."
if ! kind create cluster --name "$CLUSTER"; then
  echo "Error: failed to create kind cluster '$CLUSTER'." >&2
  exit 1
fi

helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --kube-context "$CLUSTER" \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --wait

echo
echo "ArgoCD Username: admin"
echo -n "ArgoCD Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
