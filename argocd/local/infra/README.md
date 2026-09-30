# Local infrastructure delivery

This directory defines the `infra` ArgoCD project and the tools used to promote,
deploy, and verify internal infrastructure changes in the local cluster. The
project and its four Application definitions live together so ArgoCD can manage
them as one infrastructure group.

| Definition | Purpose | Chart version | Destination namespace |
| --- | --- | --- | --- |
| [argo-cd.yaml](argo-cd.yaml) | Reconciles Kubernetes resources with the desired configuration in Git. | `5.24.1` | `argocd` |
| [kargo.yaml](kargo.yaml) | Promotes selected artifact versions between stages and uses ArgoCD to deploy them. | `1.11.5` | `kargo` |
| [cert-manager.yaml](cert-manager.yaml) | Manages TLS certificates, including the certificates used by Kargo's API and admission webhooks. | `v1.14.4` | `cert-manager` |
| [argo-rollouts.yaml](argo-rollouts.yaml) | Provides progressive delivery and the AnalysisTemplate/AnalysisRun resources Kargo uses to verify promotions. | `2.43.2` | `argo-rollouts` |

[project.yaml](project.yaml) permits these chart repositories, the Git repository,
and their destination namespaces on `in-cluster`. It also permits cluster-scoped
resources such as CRDs and RBAC. The `kube-system` destination permits
cert-manager's leader-election RBAC. Kargo creates additional namespaces for cluster
secrets, system resources, and shared resources; these are allowed by the project.

## How synchronization works

[../sync-all.yaml](../sync-all.yaml) registers the parent Application
`argo-projects-sync`, which reads this directory. The existing parent name is
retained so the ArgoCD Application keeps the same owner after moving from
`argo-projects/` to `infra/`. The project has sync wave `-1`, so it is applied
before the child Application definitions.

The parent tracks Git `HEAD`; application values sources track `main`. Local
edits must reach the tracked remote revision before ArgoCD can reconcile them.
All four applications enable automatic synchronization, pruning, and namespace
creation. Kargo, cert-manager, and Argo Rollouts also enable self-healing and
server-side apply.

ArgoCD, Kargo, and cert-manager use values from
[helm/external-values/local](../../../helm/external-values/local/). Argo Rollouts
uses its pinned chart defaults, which install its CRDs and a controller with
cluster-wide permissions. Kargo's ArgoCD and Argo Rollouts integrations are
enabled. Promotion stages, artifact subscriptions, rollout strategies, and
analysis templates must be defined separately for the infrastructure being
delivered.

## Bootstrap requirements

1. Bootstrap ArgoCD using the repository's [local cluster scripts](../../../scripts/README.md)
   and configure its access to the Git repository.
2. Provision the `kargo-api` Secret in the `kargo` namespace through the SOPS + age
   workflow. It must contain `ADMIN_ACCOUNT_PASSWORD_HASH` (a bcrypt password
   hash) and `ADMIN_ACCOUNT_TOKEN_SIGNING_KEY`. The Kargo values reference this
   existing Secret.
3. Register the parent applications from the repository root:

   ```bash
   kubectl apply -f argocd/local/sync-all.yaml
   ```

4. Confirm cert-manager and Argo Rollouts are healthy before relying on Kargo.
   Child Applications reconcile independently: the project's sync wave orders
   their definitions, but does not wait for their controllers or CRDs to become
   ready. If Kargo's first sync fails while cert-manager is starting, sync Kargo
   again after cert-manager is ready. If Kargo started before the Rollouts CRDs
   existed, restart its controller after Rollouts is ready so it detects them.

These definitions configure the local environment. Their pinned versions have
not been verified together in a running cluster.

## Validation

Render the charts with their pinned versions before changing chart settings:

```bash
helm template cert-manager cert-manager \
  --repo https://charts.jetstack.io --version v1.14.4 \
  --namespace cert-manager \
  -f helm/external-values/local/cert-manager-local.yaml

helm template argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm --version 2.43.2 \
  --namespace argo-rollouts

helm template kargo oci://ghcr.io/akuity/kargo-charts/kargo \
  --version 1.11.5 --namespace kargo \
  -f helm/external-values/local/kargo-local.yaml
```

With ArgoCD CRDs installed, validate the project and application manifests using
`kubectl apply --dry-run=server -f argocd/local/infra/`.

Upstream documentation: [Kargo installation](https://docs.kargo.io/operator-guide/basic-installation),
[Argo Rollouts installation](https://argoproj.github.io/argo-rollouts/installation/),
and [cert-manager Helm installation](https://cert-manager.io/docs/installation/helm/).
