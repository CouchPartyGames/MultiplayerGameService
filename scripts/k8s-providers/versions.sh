#!/usr/bin/env bash

: "${KIND_VERSION:=v0.27.0}"
: "${K3S_VERSION:=}" # empty = stable channel, e.g. v1.31.4+k3s1
: "${MINIKUBE_VERSION:=latest}"
: "${MINIKUBE_DRIVER:=docker}"
: "${PRE_COMMIT_VERSION:=latest}" # e.g. 4.0.1
