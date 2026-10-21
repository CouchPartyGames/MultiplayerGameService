# Helm

This directory holds the Helm values files that the ArgoCD Applications in `argocd/` use, plus a script to install the Helm CLI. ArgoCD installs the charts in the cluster. Use the Helm CLI locally to render a chart with a values file before you commit a change.

```text
helm/
├── external-values/
│   ├── local/   Values for the local cluster, grouped by area (infra/, games-orchestrator/)
│   └── prod/    Unused; there are no production ArgoCD manifests yet
├── scripts/     Helm CLI installer and version defaults
└── tools/       Native chart-testing (ct) and helmfile installers
```

Applications load these files through the multi-source pattern. One source is this repo with `ref: myRepo`, and the chart source lists `$myRepo/helm/external-values/...` under `helm.valueFiles`. When you add or move a values file, update every `$myRepo/...` path that points to it. The chart version is pinned in the Application's `targetRevision`, not in the values file.

## Scripts

Run these from the repository root.

| Script | Purpose |
| --- | --- |
| `scripts/helm-install.sh` | Install the Helm CLI on Linux or macOS (amd64 or arm64) from `get.helm.sh`. It verifies the download's SHA-256 checksum, installs to `INSTALL_DIR` (default: `/usr/local/bin`), and uses `sudo` only if that directory is not writable. |
| `scripts/version.sh` | Set the default `HELM_VERSION` (`latest`, or a release such as `v3.16.2`) `CT_VERSION`, the chart-testing version installed by `tools/ct-install.sh` and used by CI, and `HELMFILE_VERSION`, the helmfile release installed by `tools/helmfile-install.sh`. |
| `scripts/helm-lint.sh` | Run `helm lint --strict` on each chart under `helm/charts/` that contains one of the given files, or on every chart when given none. The `helm-lint` pre-commit hook runs it on staged chart files. |
| `scripts/ct-lint.sh` | Run `ct lint` with `ct.yaml` using the locally installed `ct` (no Docker), on charts changed against `main`. Extra arguments go to `ct` (for example `--all`). The `ct-lint` pre-commit hook runs it. |
| `scripts/ct-test.sh` | Run `ct install` with `ct.yaml` using the locally installed `ct`: install each chart changed against `main` into the current kube context, run its tests, and delete its namespace. Needs `kubectl` and a running local cluster. Extra arguments go to `ct` (for example `--all`). The `ct-install` pre-commit hook runs it, only on demand with `prek run ct-install --stage manual`. |
| `tools/ct-install.sh` | Install the `ct` CLI natively on Linux or macOS (amd64 or arm64), so you can run chart-testing without Docker. It downloads the `CT_VERSION` release from GitHub, verifies its SHA-256 checksum, installs `ct` to `INSTALL_DIR` (default: `/usr/local/bin`, with `sudo` only if not writable), copies ct's lint config to `~/.ct`, and installs `yamllint` and `yamale` through pipx or `pip --user` if they are missing. |
| `tools/helmfile-install.sh` | Install the `helmfile` CLI on Linux or macOS (amd64 or arm64). It downloads the `HELMFILE_VERSION` release from GitHub, verifies its SHA-256 checksum, and installs to `INSTALL_DIR` (default: `~/.local/bin` on Linux and `/usr/local/bin` on macOS, with `sudo` only if not writable). helmfile needs `helm` on PATH; run `helmfile init` to add the helm-diff plugin that `helmfile diff` and `helmfile apply` use. |

```bash
# Install the version set in version.sh
./helm/scripts/helm-install.sh

# Install a specific version (the leading "v" is optional)
HELM_VERSION=v3.16.2 ./helm/scripts/helm-install.sh

# Install somewhere that does not need sudo
INSTALL_DIR="$HOME/.local/bin" ./helm/scripts/helm-install.sh
```

The `helm` GitHub workflow (`.github/workflows/helm.yaml`) runs [chart-testing](https://github.com/helm/chart-testing) on charts under `helm/charts/` that a pull request changes: `ct lint` (yamllint, Chart.yaml schema, `helm lint`, and a chart version bump check), then `ct install` into a kind cluster. On pushes to `main` it tests every chart. Its settings are in `ct.yaml` at the repository root. Run the same steps locally with `helm/scripts/ct-lint.sh` (after `helm/tools/ct-install.sh`) and `helm/scripts/ct-test.sh`.

The default `latest` resolves to the newest Helm release when the script runs. To give everyone the same version, set a fixed release in `version.sh`.

## Quickstart

This example renders cert-manager the way `argocd/local/infra/cert-manager.yaml` deploys it. Take the chart repo, chart name, and version from the Application's chart source, and the values file from its `helm.valueFiles` entry (drop the `$myRepo/` prefix).

1. Install Helm and check it runs:

   ```bash
   ./helm/scripts/helm-install.sh
   helm version
   ```

2. Add the chart repo and refresh the index:

   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   ```

3. Look at the chart's default values to see what you can override:

   ```bash
   helm show values jetstack/cert-manager --version v1.14.4
   ```

4. Edit the values file, then render the chart with it to check the output:

   ```bash
   helm template cert-manager jetstack/cert-manager \
     --version v1.14.4 \
     --namespace cert-manager \
     -f helm/external-values/local/infra/cert-manager-local.yaml
   ```

   An error here, such as a schema violation or a template failure, would also fail the ArgoCD sync.

5. Commit and push the values change. ArgoCD syncs from `main`, so a local edit has no effect on the cluster until it is merged.

Avoid `helm install` and `helm upgrade` against the cluster for charts that ArgoCD manages. ArgoCD treats the result as drift and reverts it. The exception is the bootstrap scripts in `scripts/k8s-providers/`, which install ArgoCD itself with Helm before ArgoCD takes over.
