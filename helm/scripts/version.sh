#!/usr/bin/env bash

: "${HELM_VERSION:=latest}" # e.g. v3.16.2 or v4.3.1
: "${CT_VERSION:=v3.15.0}" # chart-testing image tag (quay.io/helmpack/chart-testing)
