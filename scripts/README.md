# Scripts

Run these commands from the repository root. The bootstrap scripts need Helm, `kubectl`, and a working container runtime or VM driver. The kind and minikube bootstrap scripts also need their cluster CLI on `PATH` and exit if it is missing; install it with the matching installer script first. Only `k3s-bootstrap.sh` installs its cluster tool itself. Minikube uses Docker by default; configure another driver with `MINIKUBE_DRIVER`.

| Script | Purpose |
| --- | --- |
| `kind-install-linux.sh` | Install kind on Linux (amd64 or arm64), replacing any existing binary. |
| `kind-install-mac.sh` | Install kind on Apple Silicon macOS, using Homebrew when available. |
| `kind-bootstrap.sh` | Create the `multiplayer-demo` kind cluster, install ArgoCD, and print the admin password. See [Local bootstrap](#local-bootstrap) for a known issue. |
| `minikube-install-linux.sh` | Install minikube on Linux (amd64 or arm64). Exits if minikube is already installed. |
| `minikube-install-mac.sh` | Install minikube on Apple Silicon macOS, using Homebrew when available. Exits if minikube is already installed. |
| `minikube-bootstrap.sh` | Start the `multiplayer-demo` minikube profile with `MINIKUBE_DRIVER` (default: `docker`), 8 CPUs, and 12 GB of memory, install ArgoCD, and print the admin password. |
| `k3s-install-linux.sh` | Install k3s on Linux with the official installer (kubeconfig at `/etc/rancher/k3s/k3s.yaml`). |
| `k3s-install-mac.sh` | k3s is Linux-only, so install k3d (k3s in Docker) on macOS and create a `k3s-local` cluster. |
| `k3s-bootstrap.sh` | Install k3s (or the k3d cluster on macOS) if missing, install ArgoCD in the `argocd` namespace, and print the admin password. |
| `argocd-cli-install-linux.sh` | Install the ArgoCD CLI on Linux (amd64 or arm64); version set by `ARGOCD_CLI_VERSION`. |
| `argocd-cli-install-mac.sh` | Install the ArgoCD CLI on macOS (Intel or Apple Silicon). Uses Homebrew when available and `ARGOCD_CLI_VERSION` is `latest`; otherwise downloads the release binary. |
| `versions.sh` | Set the default ArgoCD chart, ArgoCD CLI, kind, k3s, and minikube versions and the minikube driver for the other scripts. |

## Local bootstrap

For minikube, install the CLI if needed, then run:

```bash
./scripts/minikube-bootstrap.sh
kubectl apply -f argocd/local/sync-all-groups.yaml
```

The bootstrap script installs ArgoCD chart v10.9.5 (ArgoCD v3.5.3) as release `argo-cd` in the `argocd` namespace, using the `multiplayer-demo` Kubernetes context. It fails if the chart install does not become ready.

`argocd/local/sync-all-groups.yaml` registers three parent Applications in the `default` project: `infra-local`, `games-local`, and `games-orchestrator-local`. They read `argocd/local/infra`, `argocd/local/games`, and `argocd/local/games-orchestrator` from the repository's `HEAD` (`main`), so local edits reach the cluster only after they are pushed. `argocd/local/match-making` and `argocd/local/general` are not registered. The parents pull this repository over SSH and stay in `ComparisonError` until you [add the Git repository](#add-the-git-repository) to ArgoCD.

`kind-bootstrap.sh` passes `--kube-context multiplayer-demo` to Helm, but kind names the context `kind-multiplayer-demo`. The Helm install fails, or targets a minikube profile with that name if one exists. Until the script is fixed, run the equivalent commands directly:

```bash
kind create cluster --name multiplayer-demo
helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --kube-context kind-multiplayer-demo \
  --version 10.9.5 \
  --namespace argocd --create-namespace \
  --wait
kubectl --context kind-multiplayer-demo apply -f argocd/local/sync-all-groups.yaml
```

`kind create cluster` fails if the cluster already exists, in `kind-bootstrap.sh` as well.

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
kubectl apply -f argocd/local/sync-all-groups.yaml
```

On Linux, run `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` before the `kubectl apply` if your kubeconfig does not already point at k3s. On macOS the installer switches the current context to `k3d-k3s-local`.

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

`scripts/versions.sh` sets these defaults. Override any of them in the command environment:

| Variable | Default | Used by |
| --- | --- | --- |
| `ARGO_CD_CHART_VERSION` | `10.9.5` (ArgoCD v3.5.3) | All bootstrap scripts |
| `ARGOCD_CLI_VERSION` | `latest` | ArgoCD CLI installers |
| `KIND_VERSION` | `v0.27.0` | kind installers |
| `MINIKUBE_VERSION` | `latest` | minikube installers |
| `MINIKUBE_DRIVER` | `docker` | `minikube-bootstrap.sh` |
| `K3S_VERSION` | Empty: the k3s stable channel on Linux, k3d's bundled k3s on macOS | k3s installers |

The chart version in `versions.sh` matches `argocd/local/infra/argo-cd.yaml`, which manages ArgoCD after the `infra-local` Application syncs. Change both together.

Set `MINIKUBE_DRIVER` before bootstrapping to use another driver that is installed and configured on your machine. For example, to use Podman for bootstrap and subsequent quickstart commands in the same shell:

```bash
export MINIKUBE_DRIVER=podman
./scripts/minikube-bootstrap.sh
```

Use the same driver when starting an existing profile.

The kind, minikube, and ArgoCD CLI installers accept `INSTALL_DIR` (default `/usr/local/bin`) and use `sudo` when it is not writable. On macOS, the kind and minikube installers use `INSTALL_DIR` and the version override only when Homebrew is unavailable; the Homebrew path uses the package manager's version and location. The macOS ArgoCD CLI installer skips Homebrew whenever `ARGOCD_CLI_VERSION` is pinned.

## ArgoCD Local Quickstart

Reach the ArgoCD API server of the local cluster with a port-forward, then use the `argocd` CLI or the web UI. Install the CLI with `./scripts/argocd-cli-install-linux.sh` or `./scripts/argocd-cli-install-mac.sh`. Use a CLI version that matches the server, because a large version gap can make the login fail. The default chart runs ArgoCD v3.5.3, so pin the CLI with `ARGOCD_CLI_VERSION=v3.5.3` if `latest` has moved ahead. Check both with `argocd version`.

### Connect

Keep the port-forward running in its own terminal. `--address 127.0.0.1,::1` binds IPv4 and IPv6, so `localhost` works whichever one it resolves to:

```bash
kubectl port-forward --address 127.0.0.1,::1 svc/argo-cd-argocd-server -n argocd 4444:443
```

In a second terminal, read the initial admin password and log in. The bootstrap scripts also print this password. `argocd login` takes `host:port`, not a URL. `--insecure` is needed because the local server uses a self-signed certificate, and `--grpc-web` avoids gRPC hangs through `kubectl port-forward`:

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
argocd login 127.0.0.1:4444 --insecure --grpc-web --username admin --password "$ARGOCD_PASSWORD"
```

The web UI is at <https://localhost:4444>; sign in as `admin` with the same password and accept the certificate warning. Change the password with `argocd account update-password`.

### Add the Git repository

The manifests pull this repository over SSH (`git@github.com:CouchPartyGames/MultiplayerGameService.git`), so ArgoCD needs a key that can read it. A read-only deploy key is best:

```bash
argocd repo add git@github.com:CouchPartyGames/MultiplayerGameService.git \
  --ssh-private-key-path ~/.ssh/<key> --insecure-ignore-host-key
argocd repo list
```

`--insecure-ignore-host-key` is acceptable for a local demo only. Without a registered repo, apps show `ComparisonError: SSH agent requested but SSH_AUTH_SOCK not-specified`, and `repository not found` means the URL is misspelled or the key has no access.

### Projects and applications

| Task | Command |
| --- | --- |
| List projects | `argocd proj list` |
| Show one project | `argocd proj get <project>` |
| List applications | `argocd app list` |
| Show an application and its conditions | `argocd app get argocd/<app>` |
| Re-read Git, ignoring the cache | `argocd app get argocd/<app> --hard-refresh` |
| Sync an application | `argocd app sync argocd/<app>` |
| Show a diff against Git | `argocd app diff argocd/<app>` |
| Stream application logs | `argocd app logs argocd/<app>` |
| List registered clusters | `argocd cluster list` |
| Show the logged-in context | `argocd context` |

Replace `<project>` and `<app>` with names from the list commands. The same information is available without logging in to the API through `kubectl -n argocd get applications,appprojects`. Repository edits reach the cluster only after they are pushed to `main`.

To skip the API server altogether, `argocd --core <command>` talks to the cluster through your kubeconfig. It needs no port-forward or password, but the current namespace must be `argocd` (`kubectl config set-context --current --namespace=argocd`).
