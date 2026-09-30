#!/usr/bin/env bash
set -euo pipefail

if ! command -v minikube >/dev/null 2>&1; then
  echo "Error: minikube is not installed or is not on PATH." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required to install ArgoCD." >&2
  exit 1
fi

PROFILE="multiplayer-demo"
ARGO_CD_CHART_VERSION="5.24.1"

minikube start --profile "$PROFILE" --driver docker --memory 12288 --cpus 8

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argo-cd argo/argo-cd \
  --kube-context "$PROFILE" \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --wait
