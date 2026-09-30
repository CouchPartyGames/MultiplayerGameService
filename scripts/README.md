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

## Minikube quickstart

Install minikube with the script for your platform (both exit if minikube is already installed):

```bash
./scripts/minikube-install-linux.sh  # Linux
# Or, on Apple Silicon macOS:
./scripts/minikube-install-mac.sh
```

Follow [Local bootstrap](#local-bootstrap) for the initial cluster and ArgoCD setup. These everyday commands target the same `multiplayer-demo` profile:

| Task | Command |
| --- | --- |
| List local profiles | `minikube profile list` |
| Check cluster status | `minikube status --profile multiplayer-demo` |
| Start or resume the cluster | `minikube start --profile multiplayer-demo --driver docker --memory 12288 --cpus 8` |
| Stop the cluster, keeping its data | `minikube stop --profile multiplayer-demo` |
| List pods across namespaces | `kubectl --context multiplayer-demo get pods -A` |
| Open the Kubernetes dashboard | `minikube dashboard --profile multiplayer-demo` |
| View cluster logs | `minikube logs --profile multiplayer-demo` |
| Open a shell on the cluster node | `minikube ssh --profile multiplayer-demo` |
| List available addons | `minikube addons list --profile multiplayer-demo` |
| Get a service URL | `minikube service <service-name> --namespace <namespace> --url --profile multiplayer-demo` |
| Expose LoadBalancer services | `minikube tunnel --profile multiplayer-demo` |
| Delete the cluster and its data | `minikube delete --profile multiplayer-demo` |

Replace `<service-name>` and `<namespace>` with your service's values. Keep `minikube tunnel` running while using LoadBalancer services; it may request administrator privileges. With the Docker driver on macOS, keep `minikube service --url` running while using its URL as well.

See the [official minikube guide](https://minikube.sigs.k8s.io/docs/start/) for more examples.

## Version and install options

The defaults in `scripts/versions.sh` are ArgoCD chart v5.24.1, kind v0.27.0, and the latest minikube release. Override them through `ARGO_CD_CHART_VERSION`, `KIND_VERSION`, or `MINIKUBE_VERSION` in the command environment.

The Linux installers also accept `INSTALL_DIR` (default `/usr/local/bin`). The macOS installers accept `INSTALL_DIR` and a version override only when Homebrew is unavailable; the Homebrew path uses the package manager's version and location. Binary installation may use `sudo` when the destination is not writable.
