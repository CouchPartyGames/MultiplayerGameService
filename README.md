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

Requirements: `docker`, `kubectl`, `helm`, and either `minikube` or `kind`.

To create the `multiplayer-demo` profile and install ArgoCD in one step, run:

```bash
./scripts/minikube-bootstrap.sh
```

To create a kind cluster with the same name and install ArgoCD, run:

```bash
./scripts/kind-bootstrap.sh
```



1. Sync all groups in the environment.

   ```bash
   kubectl apply -f argocd/local/sync-all-groups.yaml
   ```

2. Open the ArgoCD UI at https://localhost:8080:

   ```bash
   kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
   ```

ArgoCD syncs from the `main` branch of the GitHub repo, so changes take effect only after they are pushed.


## Status

This is a work-in-progress demo. The local environment is the most complete. To create cloud infrastructure, follow the [GCP/GKE setup](terraform/gcp/README.md), [Azure/AKS setup](terraform/azure/README.md), or [AWS/EKS setup](terraform/aws/README.md). There are no production ArgoCD manifests yet.

## License

[MIT](LICENSE)
