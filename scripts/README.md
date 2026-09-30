# Scripts

Run these commands from the repository root. Cluster bootstrap requires Helm, the matching cluster CLI (`kind` or `minikube`), and a working container runtime or VM driver. Minikube uses Docker by default; configure another driver with `MINIKUBE_DRIVER`. The installer scripts download that CLI if it is missing; `kubectl` is needed to register the ArgoCD applications afterward.

| Script | Purpose |
| --- | --- |
| `kind-install-linux.sh` | Install kind on Linux (amd64 or arm64). |
| `kind-install-mac.sh` | Install kind on Apple Silicon macOS, using Homebrew when available. |
| `kind-bootstrap.sh` | Create the `multiplayer-demo` kind cluster and install ArgoCD.  |
| `minikube-install-linux.sh` | Install minikube on Linux (amd64 or arm64). |
| `minikube-install-mac.sh` | Install minikube on Apple Silicon macOS, using Homebrew when available. |
| `minikube-bootstrap.sh` | Start the `multiplayer-demo` minikube profile with `MINIKUBE_DRIVER` (default: `docker`), 8 CPUs, and 12 GB of memory, then install ArgoCD. |
| `k3s-install-linux.sh` | Install k3s on Linux with the official installer (kubeconfig at `/etc/rancher/k3s/k3s.yaml`). |
| `k3s-install-mac.sh` | k3s is Linux-only, so install k3d (k3s in Docker) on macOS and create a `k3s-local` cluster. |
| `k3s-bootstrap.sh` | Install k3s (or the k3d cluster on macOS) if missing, then install ArgoCD in the `argocd` namespace. |
| `argocd-cli-install-linux.sh` | Install the ArgoCD CLI on Linux (amd64 or arm64); version set by `ARGOCD_CLI_VERSION`. |
| `argocd-cli-install-mac.sh` | Install the ArgoCD CLI on macOS, using Homebrew when available; version set by `ARGOCD_CLI_VERSION`. |
| `versions.sh` | Set the default ArgoCD chart, ArgoCD CLI, kind, k3s, and minikube versions and the minikube driver for the other scripts. |

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
| Start or resume the cluster | `minikube start --profile multiplayer-demo --driver "${MINIKUBE_DRIVER:-docker}" --memory 12288 --cpus 8` |
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

## Kind quickstart

If kind is missing, run the installer for your platform:

```bash
./scripts/kind-install-linux.sh  # Linux
# Or, on Apple Silicon macOS:
./scripts/kind-install-mac.sh
```

Follow the kind commands in [Local bootstrap](#local-bootstrap) for the initial cluster and ArgoCD setup. The cluster name is `multiplayer-demo`; its Kubernetes context is `kind-multiplayer-demo`.

| Task | Command |
| --- | --- |
| Show the installed version | `kind version` |
| List local clusters | `kind get clusters` |
| Create a cluster and wait for readiness | `kind create cluster --name multiplayer-demo --wait 5m` |
| List cluster node containers | `kind get nodes --name multiplayer-demo` |
| Check cluster connectivity | `kubectl --context kind-multiplayer-demo cluster-info` |
| Check node readiness | `kubectl --context kind-multiplayer-demo get nodes` |
| List pods across namespaces | `kubectl --context kind-multiplayer-demo get pods -A` |
| Load a local Docker image | `kind load docker-image <image>:<tag> --name multiplayer-demo` |
| Load an image archive | `kind load image-archive <archive.tar> --name multiplayer-demo` |
| Export cluster logs | `kind export logs ./kind-logs --name multiplayer-demo` |
| Delete the cluster and its data | `kind delete cluster --name multiplayer-demo` |

Run the create command only when the cluster does not already exist. Replace the image and archive placeholders with your local values. For loaded images, use a non-`latest` tag and set the workload's `imagePullPolicy` to `IfNotPresent` or `Never` so Kubernetes uses the local image.

See the [official kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/) for more examples.

## K3s quickstart

k3s runs natively only on Linux. On macOS the scripts use k3d, which runs k3s inside Docker (Docker Desktop, colima, or OrbStack). Bootstrap installs whatever is missing, then installs ArgoCD:

```bash
./scripts/k3s-bootstrap.sh
kubectl apply -f argocd/local/sync-all.yaml
```

To install without ArgoCD, run `./scripts/k3s-install-linux.sh` (Linux) or `./scripts/k3s-install-mac.sh` (macOS) directly. Both are safe to re-run.

| | Linux (k3s) | macOS (k3d) |
| --- | --- | --- |
| Kubeconfig | `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` | Context `k3d-k3s-local`, set by the installer |
| Check nodes | `kubectl get nodes` | `kubectl --context k3d-k3s-local get nodes` |
| Stop | `sudo systemctl stop k3s` | `k3d cluster stop k3s-local` |
| Start | `sudo systemctl start k3s` | `k3d cluster start k3s-local` |
| Uninstall | `/usr/local/bin/k3s-uninstall.sh` | `k3d cluster delete k3s-local` |

Set `K3D_CLUSTER_NAME` to change the macOS cluster name; the context is then `k3d-<name>`. Use `INSTALL_K3S_EXEC` on Linux to pass server flags, such as `--disable traefik`; setting it replaces the default `--write-kubeconfig-mode 644`, so include that flag too if you want a kubeconfig readable without `sudo`.

See the [k3s docs](https://docs.k3s.io/) and [k3d docs](https://k3d.io/) for more.

## Version and install options

The defaults in `scripts/versions.sh` are ArgoCD chart v5.24.1, kind v0.27.0, the latest minikube release, and the k3s stable channel. Override them through `ARGO_CD_CHART_VERSION`, `KIND_VERSION`, `MINIKUBE_VERSION`, or `K3S_VERSION` in the command environment.

`MINIKUBE_DRIVER` also defaults to `docker` in `scripts/versions.sh`. Set it before bootstrapping to use another driver that is installed and configured on your machine. For example, to use Podman for bootstrap and subsequent quickstart commands in the same shell:

```bash
export MINIKUBE_DRIVER=podman
./scripts/minikube-bootstrap.sh
```

Use the same driver when starting an existing profile.

The Linux installers also accept `INSTALL_DIR` (default `/usr/local/bin`). The macOS installers accept `INSTALL_DIR` and a version override only when Homebrew is unavailable; the Homebrew path uses the package manager's version and location. Binary installation may use `sudo` when the destination is not writable.
