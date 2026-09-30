# Local development environment

This directory defines the ArgoCD applications for developing and testing the
multiplayer game service on a local Kubernetes cluster. Services are grouped
into purpose-specific directories: infrastructure delivery tools (`infra`), game
server hosting (`games-orchestrator`), game fleets (`games`), matchmaking
(`match-making`), and observability and mail (`general`). These manifests are
intended for local development and do not define a production environment.

[`sync-all-groups.yaml`](sync-all-groups.yaml) is the app-of-apps entry point.
Apply it after creating a local cluster and installing ArgoCD. It registers the
parent Applications `infra-local`, `games-local`, and
`games-orchestrator-local`, each of which tracks one directory in this
repository and lets ArgoCD reconcile the applications defined there.
`match-making/` and `general/` are not registered yet. The
[ArgoCD overview](../README.md) documents the parent mappings, bootstrap order,
and the known conflicts in the unregistered directories.

Bootstrap scripts for minikube, kind, and k3s are in
[`scripts/`](../../scripts/README.md). Before syncing, configure ArgoCD access to
the Git repository and provision the secrets the applications expect. Agones
syncs only when triggered manually, and game fleets need its CRDs. See the
[infrastructure guide](infra/README.md) for the local delivery tools and their
setup requirements, such as cert-manager and the `kargo-api` Secret for Kargo.
