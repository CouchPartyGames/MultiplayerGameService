#!/usr/bin/env bash

: "${ARGO_CD_CHART_VERSION:=5.24.1}"
: "${KIND_VERSION:=v0.27.0}"
: "${K3S_VERSION:=}" # empty = stable channel, e.g. v1.31.4+k3s1
: "${MINIKUBE_VERSION:=latest}"
: "${MINIKUBE_DRIVER:=docker}"
