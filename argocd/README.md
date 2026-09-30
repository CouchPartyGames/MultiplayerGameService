# ArgoCD manifests

This directory describes Kubernetes applications for the multiplayer service demo. `local/` targets the cluster running ArgoCD (`in-cluster`); `prod/` contains early GCP/GKE ApplicationSet examples. Cloud networks and clusters are provisioned separately through [Terraform](../terraform/README.md).

The manifests are a work in progress. The review notes below identify existing conflicts and incomplete definitions that must be resolved before syncing the full directory.

## Directory structure

Manifests are organized as `argocd/<environment>/<purpose>/`:

```text
argocd/
├── README.md
├── local/
│   ├── sync-all.yaml
│   ├── argo-projects/
│   ├── authentication/
│   ├── container-registry/
│   ├── dedicated-games/
│   ├── dedicated-hosting/
│   ├── general/
│   └── match-making/
└── prod/
    ├── agones/
    └── open-match/
```

| Layer | Purpose |
| --- | --- |
| `argocd/` | Root for GitOps application definitions and this documentation. It describes what ArgoCD should deploy; cloud infrastructure lives separately under `terraform/`. |
| `<environment>/` | Groups configuration for a deployment environment. `local/` targets the local cluster; `prod/` holds production examples. Environment-wide entry points, such as `local/sync-all.yaml`, live at this level. |
| `<purpose>/` | Groups related applications by responsibility, such as authentication, matchmaking, or dedicated game hosting. Production currently uses component names (`agones` and `open-match`) for these groups. |
| Files within `<purpose>/` | Define Applications, ApplicationSets, and usually an AppProject with repository and destination permissions. Some folders also contain supporting Kubernetes resources, such as certificates or a backup CronJob. Helm values are generally stored separately under `helm/external-values/`. |

Folder names organize the repository; each manifest's project and destination fields determine its ArgoCD permissions and deployment target. A purpose folder is included in synchronization only when an Application references it or its manifests are registered separately.

## Local components

| Directory | Components and pinned chart versions | AppProject | Target namespaces |
| --- | --- | --- | --- |
| [argo-projects](local/argo-projects/) | ArgoCD `5.24.1`; unfinished backup CronJob | `argo-projects` | `argocd` |
| [dedicated-hosting](local/dedicated-hosting/) | Agones `1.38.0`, defined as both an Application and an ApplicationSet | `hosting-local` | `agones-system` |
| [dedicated-games](local/dedicated-games/) | `simple-game-server` using the `fleet` chart `1.0.9` | `games` | `default` |
| [match-making](local/match-making/) | Open Match `1.8.1`; custom `open-match-components` chart `0.0.3` | `matchmaking-local` | `open-match` |
| [authentication](local/authentication/) | Keycloak alternatives: `keycloakx` `2.1.0` and Bitnami `keycloak` `15.1.4`; PostgreSQL `12.1.6`; OpenLDAP `4.0.2`; ingress-nginx `4.4.2`; MailHog `5.2.2` | `authentication` | `keycloak`; OpenLDAP has no destination |
| [container-registry](local/container-registry/) | Harbor `1.10.3`, Redis `17.2.0`, PostgreSQL HA `9.4.5` | `harbor`; PostgreSQL HA references an undefined `postgresql-ha` project | `default` |
| [general](local/general/) | cert-manager `v1.14.4`, self-signed issuer and allocator certificate; Prometheus `25.18.0` and operator CRDs `10.0.0`; Grafana `7.3.7`; Tempo `1.7.2`; Fluent Bit `0.46.0`; Postfix/mail `3.5.1`; MailHog `5.2.2` | Built-in `default` | `cert-manager`, `agones-system`, `monitoring`, `logging`, `default` |

Versions above are the pins in this repository, not a claim that the upstream charts have been rendered or tested together. The allocator certificate creates `allocator-tls` in `agones-system` for `127.0.0.1`, using the `selfsigned` ClusterIssuer.

## How local synchronization works

[local/sync-all.yaml](local/sync-all.yaml) is the app-of-apps entry point. It creates five parent Applications in `argocd`, each reading a directory from Git:

| Parent Application | Current source path |
| --- | --- |
| `argo-projects-sync` | `argocd/local/argo-projects` |
| `dedicated-games-sync` | `argocd/local/dedicated-games` |
| `dedicated-hosting-sync` | `argocd/local/dedicated-hosting` |
| `match-making-sync` | `argocd/local/dedicated-hosting` — currently duplicates hosting |
| `container-registry-sync` | `argocd/local/container-registry` |

The parents use the `default` project and track Git `HEAD`. Child Applications with a Git values source generally track `main` and refer to it as `myRepo`; Helm value paths begin with `$myRepo/`. Changes must reach the tracked remote Git revision before ArgoCD can reconcile them. The checked-in SSH repository URLs require appropriate repository access in ArgoCD.

All five parents enable automatic sync, pruning, and self-healing. Most child applications also enable these settings, but the Agones definitions have automatic sync commented out. Many applications request namespace creation and apply only out-of-sync resources. The parent applications' `default` destination namespace does not override namespaces explicitly set in child manifests.

`authentication/` and `general/` are not registered by `sync-all.yaml`. There is also no explicit sync-wave ordering for prerequisites such as cert-manager CRDs, Agones, and game Fleets. AppProjects allow source repositories and destinations, with broad resource-kind permissions; `general/` relies on the built-in `default` project rather than defining its own.

## Local bootstrap

Run from the repository root with a working container runtime, Helm, kubectl, and minikube or kind. The [bootstrap scripts](../scripts/README.md) create a cluster and install ArgoCD:

```bash
./scripts/minikube-bootstrap.sh
# Alternatively: ./scripts/kind-bootstrap.sh
```

Resolve the manifest issues below and configure ArgoCD's Git repository access before registering the parent applications. For minikube:

```bash
kubectl --context multiplayer-demo apply -f argocd/local/sync-all.yaml
kubectl --context multiplayer-demo -n argocd get applications,applicationsets,appprojects
```

For kind, use `--context kind-multiplayer-demo`. Applying the entry point creates the parent Applications; successful child synchronization still depends on valid manifests, allowed repositories, available charts, and prerequisite CRDs.

## Production examples

| Directory | Current configuration | Incomplete details |
| --- | --- | --- |
| [prod/agones](prod/agones/) | Agones `1.24.0`; list generator with region `us-east`, provider `gcp`, destination `in-cluster` / `agones-system` | ApplicationSet references `agones-prod`, but the project is named `hosting-prod`; templated label values are unquoted and fail YAML parsing. |
| [prod/open-match](prod/open-match/) | Open Match `1.3.0`; list generator with region `us-east`, provider `gcp`, destination `gcp-us_east` / `guestbook` | References an undefined `infra` project; project file is empty; ApplicationSet namespace is omitted; templated label values fail YAML parsing. |

There is no production app-of-apps entry point. Neither production ApplicationSet references the production values files under `helm/external-values/`. Their `provider: gcp` labels describe generator data; they do not provision or register clusters. Configure real destinations and projects before using them with GKE, AKS, or EKS. Local and production ApplicationSets also reuse the names `agones-appset` and `open-match-appset`, so they must be renamed or isolated if managed in the same ArgoCD namespace.

## Review notes: current deployment blockers

These findings come from inspecting the checked-in manifests and checking YAML syntax and referenced values paths. No live cluster sync or chart rendering was performed.

| Area | Finding |
| --- | --- |
| Parent routing | `match-making-sync` points at `dedicated-hosting`; authentication and general have no parent entries. |
| Duplicate Agones application | The standalone Agones Application and its ApplicationSet both define `agones-local`. Choose one owner. |
| Duplicate matchmaking application | `components.yaml`, `open-match-app.yaml`, and the ApplicationSet template all use `open-match-local`. The components application needs a distinct name, and the core deployment needs one owner. |
| Duplicate authentication names | Both Keycloak alternatives and `openldap-ha.yaml` use the Application name `keycloak`. OpenLDAP also lacks `spec.destination`. |
| Duplicate general names | `cert-manager.yaml`, `mailhog.yaml`, and `tempo.yaml` all name their Application `cert-manager`. |
| Cross-area database name | Authentication PostgreSQL and registry PostgreSQL HA both use Application name `postgresql` in `argocd`. |
| Missing values | Agones references `$myRepo/agones-local.yaml`, but the file is at `helm/external-values/agones-local.yaml`. Matchmaking components references the absent `helm/external-values/open-match-components-local.yaml`. |
| Repository permissions | `matchmaking-local` does not allow the custom components chart repository. `authentication` does not allow the OpenLDAP or Bitnami OCI repository URLs used by its applications. |
| Chart/value selection | ingress-nginx points at the Codecentric chart repository and needs its chart source verified. The Bitnami Keycloak alternative references `keycloak-local.yaml` despite a separate `keycloak-bitnami-local.yaml` being present; verify the chart-specific values before selecting it. |
| Undefined project | Registry PostgreSQL HA references `postgresql-ha`, but the folder only defines `harbor`. |
| YAML syntax | The ArgoCD backup CronJob and hosting project contain tabs that fail YAML parsing. Both production ApplicationSets fail parsing on unquoted template expressions. |
| Backup placeholder | The backup CronJob has no image, incomplete command arguments and pod configuration, and no working backup destination. It is not a usable backup implementation. |

## Editing and validation

Keep chart versions and values paths aligned, and ensure every application's `spec.project`, source repositories, and destination match its AppProject. Use two-space YAML indentation and unique Application names within the ArgoCD namespace. Store new secrets through the repository's SOPS and age workflow.

Render changed Helm values using the chart version pinned in the relevant manifest:

```bash
helm template <release> <repo>/<chart> \
  --version <targetRevision> \
  -f helm/external-values/<values-file>.yaml
```

Where a suitable cluster has the required CRDs installed, validate changed manifests before syncing:

```bash
kubectl apply --dry-run=server -f <manifest.yaml>
```

Server validation checks resource schemas; chart rendering and ArgoCD sync status are still needed to verify source access, values compatibility, and application dependencies.
