# MultiplayerServiceDemo

Multiplayer game backend demo using [Agones](https://agones.dev) for dedicated game server hosting and [Open Match](https://open-match.dev) for matchmaking. It is deployed to Kubernetes with [ArgoCD](https://argo-cd.readthedocs.io).

This repository contains only infrastructure: ArgoCD manifests, Helm values, and bootstrap scripts.

## Stack

| Area | Components |
| --- | --- |
| Dedicated hosting | Agones |
| Matchmaking | Open Match |
| Game servers | Agones Fleet (`simple-game-server`) |
| Authentication | Keycloak, OpenLDAP, PostgreSQL |
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
docker/           Custom Keycloak image (themes and SPIs)
terraform/        Infrastructure as code (in progress)
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

The separate commands below use the existing `openmatch` profile.

1. Start a minikube cluster. This uses the `openmatch` profile with 8 CPUs and 12 GB of memory:

   ```bash
   ./scripts/minikube.sh
   ```

2. Install ArgoCD:

   ```bash
   ./scripts/install-argocd.sh
   ```

3. Point ArgoCD at this repository:

   ```bash
   kubectl apply -f argocd/local/sync-all.yaml
   ```

4. Open the ArgoCD UI at https://localhost:8080:

   ```bash
   kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
   ```

ArgoCD syncs from the `main` branch of the GitHub repo, so changes take effect only after they are pushed.

To install components without ArgoCD, use `scripts/install-agones.sh`, `scripts/install-open-match.sh`, and `scripts/install-observability.sh` instead.

## Status

This is a work-in-progress demo. The local environment is the most complete. Production (GKE) and the Terraform setup are still being built.

## License

[MIT](LICENSE)
