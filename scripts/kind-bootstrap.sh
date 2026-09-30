#!/usr/bin/env bash
set -euo pipefail

if ! command -v kind >/dev/null 2>&1; then
  echo "Error: kind is not installed or is not on PATH." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required to install ArgoCD." >&2
  exit 1
fi

CLUSTER="multiplayer-demo"
ARGO_CD_CHART_VERSION="5.24.1"

kind create cluster --name "$CLUSTER"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argo-cd argo/argo-cd \
  --kube-context "kind-$CLUSTER" \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --wait
