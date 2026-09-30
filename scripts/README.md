# Scripts

Run these commands from the repository root. The bootstrap scripts need a working container runtime, `helm`, and the matching Kubernetes CLI (`kind` or `minikube`). Use the install script for your operating system first if that CLI is missing.

| Script | Purpose |
| --- | --- |
| `kind-install-linux.sh` | Install kind on Linux (amd64 or arm64). Defaults to v0.27.0. |
| `kind-install-mac.sh` | Install kind on Apple Silicon macOS, using Homebrew when available. Defaults to v0.27.0 for the binary download. |
| `kind-bootstrap.sh` | Create the `multiplayer-demo` kind cluster and install ArgoCD chart v5.24.1. |
| `minikube-install-linux.sh` | Install minikube on Linux (amd64 or arm64). Defaults to the latest release. |
| `minikube-install-mac.sh` | Install minikube on Apple Silicon macOS, using Homebrew when available. Defaults to the latest release for the binary download. |
| `minikube-bootstrap.sh` | Create the `multiplayer-demo` minikube profile with the Docker driver, 8 CPUs, and 12 GB of memory, then install ArgoCD chart v5.24.1. |
| `install-argocd.sh` | Install ArgoCD chart v5.8.5 in the current Kubernetes context and set a fixed admin password. |
| `install-observability.sh` | Attempt to install Prometheus, Prometheus Operator CRDs, Grafana, and Loki in the current Kubernetes context. See the note below. |

For a local cluster, choose one bootstrap path:

```bash
./scripts/kind-bootstrap.sh
# or
./scripts/minikube-bootstrap.sh
```

Then register the local ArgoCD applications:

```bash
kubectl apply -f argocd/local/sync-all.yaml
```

The Linux installers accept `INSTALL_DIR` and `KIND_VERSION` or `MINIKUBE_VERSION` overrides. The macOS installers accept the same overrides for their binary download path; Homebrew installs ignore them. The installers may use `sudo` when the destination is not writable.

**Manual install notes:** `install-argocd.sh` uses the current Kubernetes context and configures a hard-coded admin password, so avoid it for a shared cluster. `install-observability.sh` has a broken line continuation in its Prometheus command and does not add the Helm repositories it references; it needs correction before use.
