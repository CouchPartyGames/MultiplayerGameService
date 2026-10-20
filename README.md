# MultiplayerServiceDemo

Multiplayer game backend demo using [Agones](https://agones.dev) for dedicated game server hosting and [Open Match](https://open-match.dev) for matchmaking. It is deployed to Kubernetes with [ArgoCD](https://argo-cd.readthedocs.io).

This repository contains only infrastructure: ArgoCD manifests, Helm values, and bootstrap scripts.

## Stack

| Area | Components |
| --- | --- |
| Dedicated hosting | Agones |
| Matchmaking | Open Match |
| Game servers | Agones Fleet (`simple-game-server`) |
| Authentication | Keycloak, PostgreSQL |
| Container registry | Harbor |
| Observability | Prometheus, Grafana, Tempo, Fluent Bit |
| General | cert-manager, ingress-nginx, Postfix / MailHog |
| Cloud infrastructure | Terraform, Atlantis |
| Delivery | ArgoCD, Kargo, Argo Rollouts, with SOPS + age for secrets |

## Repository layout

```
argocd/
  CODING-STANDARD.md   Standard for ArgoCD manifests and values files
  README.md            ArgoCD overview and review notes
  local/               ArgoCD projects and apps for the local cluster
    sync-all-groups.yaml   App-of-apps entry point (infra, games, games-orchestrator)
    infra/                 ArgoCD, Kargo, cert-manager, Argo Rollouts, Atlantis
    games-orchestrator/    Agones
    games/                 Sample game Fleet (simple-game-server)
    match-making/          Open Match (not registered in sync-all-groups.yaml)
    general/               Observability, certificates, and mail apps (not registered)
helm/external-values/
  local/               Helm values files referenced by the ArgoCD apps
    infra/, games-orchestrator/   Values grouped by area (older files sit directly in local/)
  prod/                Unused
scripts/               Cluster bootstrap (minikube, kind, k3s) and CLI installers
terraform/envs/        Terraform root modules, one per cloud account
terraform/modules/     Terraform child modules: GKE, AKS, EKS, and an S3 state backend
```

Every folder under `argocd/local/` except `general/` defines its own ArgoCD `AppProject`; `general/` uses the built-in `default` project. Most apps have two sources: the upstream Helm chart, and this repository, referenced as `$myRepo`, which provides the values files from `helm/external-values/`.

## How the project uses GitOps

Git is the source of truth for both the cloud infrastructure and the applications that run on it. Changes are proposed in pull requests, and tooling applies them from Git rather than by hand. The work is split into two layers.

### Layer 1: Infrastructure

[Atlantis](https://www.runatlantis.io) and [Terraform](https://www.terraform.io) provision cloud resources on AWS, GCP, and Azure. Each cloud has its own configuration under `terraform/` (EKS, GKE, and AKS, with their networking and IAM). When a pull request changes Terraform, Atlantis runs `terraform plan` and posts the result on the pull request; a comment runs `terraform apply`.

Atlantis itself runs in the cluster as an ArgoCD Application ([argocd/local/infra/atlantis.yaml](argocd/local/infra/atlantis.yaml)). It needs a hand-created `atlantis-vcs` Secret, and GitHub webhooks need a tunnel to reach a local cluster; see [argocd/local/infra/README.md](argocd/local/infra/README.md#bootstrap-requirements).

### Layer 2: Application

[ArgoCD](https://argo-cd.readthedocs.io) and [Kargo](https://kargo.io) deliver applications into Kubernetes clusters. ArgoCD reconciles each cluster with the manifests under `argocd/` and the Helm values under `helm/external-values/`, starting from the app-of-apps entry point `argocd/local/sync-all-groups.yaml`. Kargo promotes artifact versions between stages and uses ArgoCD to deploy them, with Argo Rollouts verifying each promotion.

Today, only the local cluster is wired up, and Kargo promotion stages are not defined yet. Nothing in `argocd/` targets the Terraform-provisioned cloud clusters.

## Getting started (local)

Requirements: `docker`, `kubectl`, `helm`, and one of `minikube`, `kind`, or k3s.

To create the `multiplayer-demo` profile and install ArgoCD in one step, run:

```bash
./scripts/k8s-providers/minikube-bootstrap.sh
```

To create a kind cluster with the same name and install ArgoCD, run:

```bash
./scripts/k8s-providers/kind-bootstrap.sh
```

To use k3s instead, run the following command. It installs k3s on Linux, or a k3d cluster named `k3s-local` on macOS, if one is missing, then installs ArgoCD:

```bash
./scripts/k8s-providers/k3s-bootstrap.sh
```

On Linux, run `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` before the steps below if your kubeconfig does not already point at k3s. On macOS, the script switches the current context to `k3d-k3s-local`. See [scripts/README.md](scripts/README.md#k3s-quickstart) for more k3s commands.

After bootstrapping:

1. Sync all groups in the environment.

   ```bash
   kubectl apply -f argocd/local/sync-all-groups.yaml
   ```

2. Open the ArgoCD UI at https://localhost:8080:

   ```bash
   kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
   ```

ArgoCD syncs from the `main` branch of the GitHub repo, so changes take effect only after they are pushed.

## Stopping and deleting the local cluster

Stopping frees CPU and memory but keeps the cluster, ArgoCD, and synced apps for the next start. Deleting removes the cluster and all of its data; run the bootstrap script again to recreate it.

| Cluster | Stop | Start again | Delete |
| --- | --- | --- | --- |
| minikube | `minikube stop --profile multiplayer-demo` | `minikube start --profile multiplayer-demo` | `minikube delete --profile multiplayer-demo` |
| kind | `docker stop multiplayer-demo-control-plane` | `docker start multiplayer-demo-control-plane` | `kind delete cluster --name multiplayer-demo` |
| k3s (Linux) | `/usr/local/bin/k3s-killall.sh` | `sudo systemctl start k3s` | `/usr/local/bin/k3s-uninstall.sh` |
| k3d (macOS) | `k3d cluster stop k3s-local` | `k3d cluster start k3s-local` | `k3d cluster delete k3s-local` |

- **minikube:** start an existing profile with the driver it was created with. If you bootstrapped with a non-default `MINIKUBE_DRIVER`, add `--driver "$MINIKUBE_DRIVER"`.
- **kind:** kind has no stop command, so stop and start the cluster's node container with Docker. `kind-bootstrap.sh` fails if the cluster already exists, so use `docker start` rather than the bootstrap script to bring a stopped cluster back.
- **k3s:** `sudo systemctl stop k3s` stops only the k3s service; pods and their containers keep running. `k3s-killall.sh` stops the service, all containers, and k3s networking. k3s also starts again on boot; run `sudo systemctl disable k3s` to prevent that. The uninstall script removes k3s and all cluster data. Both scripts rerun themselves with `sudo`.
- **k3d:** if you set `K3D_CLUSTER_NAME`, use that name instead of `k3s-local`.


## Status

This is a work-in-progress demo. The local environment is the most complete. To create cloud infrastructure, follow the [GCP/GKE setup](terraform/modules/gcp/gke/README.md), [Azure/AKS setup](terraform/modules/azure/aks/README.md), or [AWS/EKS setup](terraform/modules/aws/eks/README.md). There are no production ArgoCD manifests yet.

## License

[MIT](LICENSE)
