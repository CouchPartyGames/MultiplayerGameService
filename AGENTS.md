# Repository Guidelines

## Project Structure & Module Organization

This repository contains Kubernetes infrastructure for a multiplayer game demo, not application source code. `argocd/local/` holds ArgoCD projects and applications for minikube; `argocd/prod/` contains early GKE configurations. `argocd/local/sync-all.yaml` is the local app-of-apps entry point. Chart settings live in `helm/external-values/`, bootstrap and manual installation scripts in `scripts/`, and the custom Keycloak image in `docker/keycloak-custom/`. `terraform/` and `gitops/` are placeholders. There are no test or asset directories.

## Build, Test, and Development Commands

- `./scripts/minikube.sh` starts the local `openmatch` cluster (8 CPUs, 12 GB RAM).
- `./scripts/install-argocd.sh` installs ArgoCD after the cluster starts.
- `kubectl apply -f argocd/local/sync-all.yaml` registers the local applications.
- `helm template <release> <repo>/<chart> --version <targetRevision> -f helm/external-values/<file>.yaml` renders a chart with changed values. Use the version pinned in its ArgoCD manifest.
- `kubectl apply --dry-run=server -f <manifest.yaml>` validates Kubernetes manifests against a cluster with the required CRDs.

There is no repository-wide build command or automated test suite. ArgoCD tracks `main`, so local edits reach the cluster only after they are pushed.

## Coding Style & Naming Conventions

Use two spaces for YAML indentation and spaces, never tabs. Keep environment-specific names explicit, such as `agones-local.yaml` and `agones-prod.yaml`. Place new ArgoCD applications under the matching `argocd/<environment>/<area>/` directory. Keep `spec.project` aligned with that area's AppProject and ensure chart repositories appear in its `sourceRepos`. When moving a values file, update every `$myRepo/helm/external-values/...` reference. Follow existing Bash script conventions and quote variable expansions.

## Testing Guidelines

For shell changes, run `bash -n <script>`. For chart values, render the pinned chart with `helm template`; for ArgoCD manifests, use the server dry run above where a suitable cluster is available. Inspect the rendered resources and referenced paths before committing. No coverage target or test naming convention applies.

## Commit & Pull Request Guidelines

Recent commits commonly use `chore:`, `fix:`, or `feat:` followed by a short imperative description, for example `chore: bump agones values`. Keep each commit focused. In pull requests, describe the affected environment and components, link a relevant issue when one exists, and include validation commands and results. Add screenshots only for visible UI changes.

## Secrets & Configuration

Use the repository's SOPS and age workflow for new secrets; do not add plaintext credentials. Check chart versions and values paths together when updating an application.
