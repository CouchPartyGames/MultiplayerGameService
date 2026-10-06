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
| Delivery | ArgoCD, with SOPS + age for secrets |

## Repository layout

```
argocd/
  CODING-STANDARD.md   Standard for ArgoCD manifests and values files
  README.md            ArgoCD overview and review notes
  local/               ArgoCD projects and apps for the local cluster
    sync-all-groups.yaml   App-of-apps entry point (infra, games, games-orchestrator)
    infra/                 ArgoCD, Kargo, cert-manager, Argo Rollouts
    games-orchestrator/    Agones
    games/                 Sample game Fleet (simple-game-server)
    match-making/          Open Match (not registered in sync-all-groups.yaml)
    general/               Observability, certificates, and mail apps (not registered)
helm/external-values/
  local/               Helm values files referenced by the ArgoCD apps
    infra/, games-orchestrator/   Values grouped by area (older files sit directly in local/)
  prod/                Unused
scripts/               Cluster bootstrap (minikube, kind, k3s), CLI installers, versions.sh
terraform/gcp/         Terraform for a GCP VPC, subnet, and GKE Standard cluster
terraform/azure/       Terraform for an Azure virtual network, subnet, and AKS cluster
terraform/aws/         Terraform for an AWS VPC, subnets, and EKS cluster
```

Every folder under `argocd/local/` except `general/` defines its own ArgoCD `AppProject`; `general/` uses the built-in `default` project. Most apps have two sources: the upstream Helm chart, and this repository, referenced as `$myRepo`, which provides the values files from `helm/external-values/`.

## Getting started (local)

Requirements: `docker`, `kubectl`, `helm`, and one of `minikube`, `kind`, or k3s.

To create the `multiplayer-demo` profile and install ArgoCD in one step, run:

```bash
./scripts/minikube-bootstrap.sh
```

To create a kind cluster with the same name and install ArgoCD, run:

```bash
./scripts/kind-bootstrap.sh
```

To use k3s instead, run the following command. It installs k3s on Linux, or a k3d cluster named `k3s-local` on macOS, if one is missing, then installs ArgoCD:

```bash
./scripts/k3s-bootstrap.sh
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

This is a work-in-progress demo. The local environment is the most complete. To create cloud infrastructure, follow the [GCP/GKE setup](terraform/gcp/README.md), [Azure/AKS setup](terraform/azure/README.md), or [AWS/EKS setup](terraform/aws/README.md). There are no production ArgoCD manifests yet.

## License

[MIT](LICENSE)
