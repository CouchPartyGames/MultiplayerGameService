# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure/GitOps config for a multiplayer game backend demo built on **Agones** (dedicated game server hosting) and **Open Match** (matchmaking), deployed to Kubernetes via **ArgoCD**. There is no application source code, build, or test suite: the repo is YAML manifests, Helm values, shell scripts, and Terraform. The GitOps manifests pull this repo over SSH as `git@github.com:CouchPartyGames/MultiplayerGameService.git`.

## Layout and how the pieces connect

- `argocd/local/<area>/` holds ArgoCD `AppProject`, `Application`, and `ApplicationSet` manifests. Each area except `general/` has a `project.yaml`; an app's `spec.project` must match that project's name, and its chart repo must be listed in the project's `sourceRepos`. `general/` uses the built-in `default` project. Write manifests and values files to `argocd/CODING-STANDARD.md`.
- `argocd/local/sync-all-groups.yaml` is the app-of-apps entry point. It registers the parents `infra-local`, `games-local`, and `games-orchestrator-local`, which read those directories on `HEAD`. `match-making/` and `general/` are not registered. The cluster syncs what is pushed to `main`, so local edits have no effect until pushed.
- `helm/external-values/<env>/<area>/` holds Helm values files that Applications use through the multi-source pattern: one source is this repo with `ref: myRepo`, and the chart source references `$myRepo/helm/external-values/...`. That path is relative to the repo root, so when you add or move a values file, update every `$myRepo/...` path that points to it. Older values files still sit directly in `helm/external-values/local/`.
- Chart versions are pinned in the Application/ApplicationSet `targetRevision`, not in values files.
- `argocd/local/infra/argo-cd.yaml` manages the ArgoCD install itself (release `argo-cd`, the same one the bootstrap scripts create). Change its `targetRevision` together with `ARGO_CD_CHART_VERSION` in `scripts/versions.sh`.
- `scripts/` holds the imperative steps that run outside ArgoCD: cluster bootstrap for minikube, kind, and k3s (each installs ArgoCD via Helm), CLI installers, and shared version defaults in `versions.sh`. `scripts/README.md` documents them and the ArgoCD CLI workflow.
- `terraform/` holds separate GCP/GKE, Azure/AKS, and AWS/EKS cluster configurations and Terraform installers. Nothing in `argocd/` targets those clusters yet.

## Environments

Only **local** exists: a minikube or kind cluster named `multiplayer-demo`, or k3s (a k3d cluster named `k3s-local` on macOS). It covers infrastructure delivery (ArgoCD, Kargo, cert-manager, Argo Rollouts), Agones, a sample game Fleet, Open Match, and observability/mail apps. There are no production ArgoCD manifests; `helm/external-values/prod/` is unused.

## Secrets

SOPS + age is the intended secrets workflow, but it is not wired up: ArgoCD has no helm-secrets plugin configured and the repo holds no age key. Secrets the charts expect, such as `kargo-api` in the `kargo` namespace, are created by hand (see `argocd/local/infra/README.md`). Keep plaintext credentials out of committed files.

## Useful commands

```bash
# Local cluster + ArgoCD bootstrap
./scripts/minikube-bootstrap.sh
kubectl apply -f argocd/local/sync-all-groups.yaml

# ArgoCD UI and CLI at https://localhost:4444
kubectl port-forward svc/argo-cd-argocd-server -n argocd 4444:443

# Render a chart with a values file before committing a values change
helm template <release> <repo>/<chart> --version <targetRevision> -f helm/external-values/<env>/<area>/<app>-<env>.yaml
```

Validate manifest edits with `kubectl apply --dry-run=server -f <file>` against a cluster that has ArgoCD CRDs installed, and shell edits with `bash -n <script>`.

## Known inconsistencies

Before assuming a manifest works as written, check the blocker list under "Review notes" in `argocd/README.md` (duplicate Application names, missing values files, project permissions, manual Agones sync). When you fix one, remove it from that list.
