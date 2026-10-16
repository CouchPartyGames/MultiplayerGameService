#!/usr/bin/env bash

: "${ARGO_CD_CHART_VERSION:=10.9.5}" # keep in sync with argocd/local/infra/argo-cd.yaml targetRevision
: "${KIND_VERSION:=v0.27.0}"
: "${K3S_VERSION:=}" # empty = stable channel, e.g. v1.31.4+k3s1
: "${MINIKUBE_VERSION:=latest}"
: "${MINIKUBE_DRIVER:=docker}"
