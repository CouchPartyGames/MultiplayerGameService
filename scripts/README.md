# Scripts

Run these commands from the repository root. Cluster bootstrap requires a working Docker-compatible container runtime, Helm, and the matching cluster CLI (`kind` or `minikube`). The installer scripts download that CLI if it is missing; `kubectl` is needed to register the ArgoCD applications afterward.

| Script | Purpose |
| --- | --- |
| `kind-install-linux.sh` | Install kind on Linux (amd64 or arm64). |
| `kind-install-mac.sh` | Install kind on Apple Silicon macOS, using Homebrew when available. |
| `kind-bootstrap.sh` | Create the `multiplayer-demo` kind cluster and install ArgoCD.  |
| `minikube-install-linux.sh` | Install minikube on Linux (amd64 or arm64). |
| `minikube-install-mac.sh` | Install minikube on Apple Silicon macOS, using Homebrew when available. |
| `minikube-bootstrap.sh` | Start the `multiplayer-demo` minikube profile with the Docker driver, 8 CPUs, and 12 GB of memory, then install ArgoCD. |
| `versions.sh` | Set the default ArgoCD chart, kind, and minikube versions for the other scripts. |

## Local bootstrap

For minikube, install the CLI if needed, then run:

```bash
./scripts/minikube-bootstrap.sh
kubectl apply -f argocd/local/sync-all.yaml
```

The bootstrap script installs ArgoCD chart v5.24.1 in the `argocd` namespace using the `multiplayer-demo` Kubernetes context. The application manifests in `argocd/local/sync-all.yaml` track `main`, so local repository edits reach the cluster only after they are pushed.

```bash
kind create cluster --name multiplayer-demo
helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --kube-context kind-multiplayer-demo \
  --version 5.24.1 \
  --namespace argocd --create-namespace \
  --wait
kubectl --context kind-multiplayer-demo apply -f argocd/local/sync-all.yaml
```

## Version and install options

The defaults in `scripts/versions.sh` are ArgoCD chart v5.24.1, kind v0.27.0, and the latest minikube release. Override them through `ARGO_CD_CHART_VERSION`, `KIND_VERSION`, or `MINIKUBE_VERSION` in the command environment.

The Linux installers also accept `INSTALL_DIR` (default `/usr/local/bin`). The macOS installers accept `INSTALL_DIR` and a version override only when Homebrew is unavailable; the Homebrew path uses the package manager's version and location. Binary installation may use `sudo` when the destination is not writable.
