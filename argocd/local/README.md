# Local development environment

This directory defines the ArgoCD applications for developing and testing the
multiplayer game service on a local Kubernetes cluster. It groups services such
as authentication, matchmaking, game hosting, observability, and infrastructure
delivery tools into purpose-specific directories. These manifests are intended
for local development and do not define the production environment.

[`sync-all.yaml`](sync-all.yaml) is the app-of-apps entry point. Apply it after
creating a local cluster and installing ArgoCD to register the parent
Applications. Each parent tracks a directory in this repository and lets
ArgoCD reconcile the applications defined there. The current parent mappings
and setup details are documented in the [ArgoCD overview](../README.md).

Bootstrap scripts for minikube and kind are in [`scripts/`](../../scripts/README.md).
Before syncing, configure ArgoCD access to the Git repository and make sure
required dependencies, such as cert-manager for Kargo, are ready. See the
[infrastructure guide](infra/README.md) for the local delivery tools and their
setup requirements.
