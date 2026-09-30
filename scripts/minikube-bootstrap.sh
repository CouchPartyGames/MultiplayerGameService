#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

if ! command -v minikube >/dev/null 2>&1; then
  echo "Error: minikube is not installed or is not on PATH." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required to install ArgoCD." >&2
  exit 1
fi

PROFILE="multiplayer-demo"

if ! minikube start --profile "$PROFILE" --driver $MINIKUBE_DRIVER --memory 12288 --cpus 8; then
  echo "Error: failed to create minikube cluster '$PROFILE'." >&2
  exit 1
fi

helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --kube-context "$PROFILE" \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --wait

echo
echo "ArgoCD Username: admin"
echo -n "ArgoCD Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
