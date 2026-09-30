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
  local/          ArgoCD projects and apps for a local minikube cluster
    sync-all.yaml   App-of-apps entry point (one sync app per area)
  prod/           Production (GKE) skeletons for Agones and Open Match
helm/external-values/   Helm values files referenced by the ArgoCD apps
scripts/          Cluster bootstrap and manual Helm install scripts
terraform/gcp/    Terraform for a GCP VPC, subnet, and GKE Standard cluster
terraform/azure/  Terraform for an Azure virtual network, subnet, and AKS cluster
terraform/aws/    Terraform for an AWS VPC, subnets, and EKS cluster
```

Every folder under `argocd/local/` defines its own ArgoCD `AppProject`. Most apps have two sources: the upstream Helm chart, and this repository, referenced as `$myRepo`, which provides the values files from `helm/external-values/`.

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

This is a work-in-progress demo. The local environment is the most complete. To create cloud infrastructure, follow the [GCP/GKE setup](terraform/gcp/README.md), [Azure/AKS setup](terraform/azure/README.md), or [AWS/EKS setup](terraform/aws/README.md). The production ArgoCD manifests are still skeletons.

## License

[MIT](LICENSE)
