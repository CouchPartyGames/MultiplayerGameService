# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure/GitOps config for a multiplayer game backend demo built on **Agones** (dedicated game server hosting) and **Open Match** (matchmaking), deployed to Kubernetes via **ArgoCD**. There is no application source code, build, or test suite: the repo is YAML manifests, Helm values, and shell scripts. The GitOps manifests use `git@github.com:CouchPartyGames/MultiplayerGameService.git`.

## Layout and how the pieces connect

- `argocd/<env>/<area>/` holds ArgoCD `AppProject`, `Application`, and `ApplicationSet` manifests. Each area directory (`dedicated-hosting`, `match-making`, `dedicated-games`, `authentication`, `container-registry`, `general`, `argo-projects`) has a `project.yaml` defining the AppProject that its apps belong to. An app's `spec.project` must match that project's name, and its chart repo must be listed in the project's `sourceRepos`.
- `argocd/local/sync-all.yaml` is the app-of-apps entry point. It creates one `*-sync` Application per area directory, pointing ArgoCD at that path on `HEAD`. Changes pushed to `main` are what the cluster syncs, so local edits have no effect until pushed.
- `helm/external-values/` holds Helm values files that ArgoCD Applications use through the multi-source pattern: one source is this git repo with `ref: myRepo`, and the chart source references `$myRepo/helm/external-values/...`. That path is relative to the repo root, so when you add or move a values file, update every `$myRepo/...` path that points to it.
- Chart versions are pinned in the Application/ApplicationSet `targetRevision`, not in the values files.
- `scripts/` holds imperative bootstrap scripts that run outside ArgoCD: `minikube.sh` (local cluster, profile `openmatch`), `install-argocd.sh` (installs ArgoCD via Helm, which must run first), and `install-agones.sh` / `install-open-match.sh` / `install-observability.sh` (manual Helm installs as an alternative to ArgoCD). `cloud-gcp.sh` is a placeholder `gcloud` GKE create command.
- `terraform/` and `gitops/` are empty placeholders.
- `docker/keycloak-custom/` builds a Keycloak image with custom themes and SPIs.

## Environments

- **local** (minikube) is the most complete environment. `argocd/local/` covers hosting, matchmaking, games, auth (Keycloak/OpenLDAP/Postgres), Harbor registry, and observability (Prometheus, Grafana, Tempo, Fluent Bit, cert-manager).
- **prod** (`argocd/prod/`) only has Agones and Open Match skeletons, targeting GKE (`provider: gcp`).

## Secrets

Secrets are meant to be encrypted with SOPS + age and decrypted by ArgoCD through helm-secrets (see the commented `secrets+age-import-kubernetes://` value files in `argocd/local/argo-projects/argo-cd.yaml`). The local age key lives in `data/age-local.txt` and is also injected by `helm/external-values/local/argocd-local.yaml`. These are local/demo credentials only.

## Useful commands

```bash
# Local cluster + ArgoCD bootstrap
./scripts/minikube.sh
./scripts/install-argocd.sh
kubectl apply -f argocd/local/sync-all.yaml

# ArgoCD UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443

# Render a chart with a values file before committing a values change
helm template <release> <repo>/<chart> --version <targetRevision> -f helm/external-values/<env>/<app>-<env>.yaml
```

Validate manifest edits with `kubectl apply --dry-run=server -f <file>` against a cluster that has ArgoCD CRDs installed.

## Known inconsistencies

Check for these before assuming a manifest works as written:
- `sync-all.yaml`: `match-making-sync` points at `argocd/local/dedicated-hosting` instead of `match-making`. `general/` and `authentication/` have no sync app.
- Duplicate Application names in the same namespace, where the last one applied wins: `agones-local` in both `agones-app.yaml` and `agones-appset.yaml`; `open-match-local` in `open-match-app.yaml`, `components.yaml`, and the appset. `mailhog.yaml` and `tempo.yaml` in `general/` are both named `cert-manager`.
- `components.yaml` references `open-match-components-local.yaml`, which does not exist.
- In prod, the Agones appset uses project `agones-prod`, but the AppProject is named `hosting-prod`. Its labels `{{region}}` / `{{provider}}` are unquoted, which is invalid YAML.
- `argocd/local/argo-projects/argo-cd-backup.yaml` uses tab indentation and is invalid YAML.
