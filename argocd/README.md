# ArgoCD manifests

This directory describes the Kubernetes applications for the multiplayer service demo. Its only environment is `local/`, which deploys to the cluster running ArgoCD (`in-cluster`). There are no production manifests; the values files under `helm/external-values/prod/` are not referenced by any Application. Cloud networks and clusters are provisioned separately through [Terraform](../terraform/README.md).

The manifests are a work in progress. The review notes below list the conflicts and incomplete definitions that must be resolved before the unregistered directories can be synced.

## Directory structure

Manifests are organized as `argocd/<environment>/<purpose>/`:

```text
argocd/
├── README.md
├── CODING-STANDARD.md
└── local/
    ├── README.md
    ├── sync-all-groups.yaml
    ├── games/
    ├── games-orchestrator/
    ├── general/
    ├── infra/
    └── match-making/
```

| Layer | Purpose |
| --- | --- |
| `argocd/` | Root for GitOps application definitions and this documentation. It describes what ArgoCD should deploy; cloud infrastructure lives separately under `terraform/`. |
| `<environment>/` | Groups configuration for a deployment environment. Only `local/` exists. Environment-wide entry points, such as `local/sync-all-groups.yaml`, live at this level. |
| `<purpose>/` | Groups related applications by responsibility, such as infrastructure delivery, matchmaking, or dedicated game hosting. |
| Files within `<purpose>/` | Define Applications, ApplicationSets, and usually an AppProject with repository and destination permissions. `general/` also contains cert-manager resources (a ClusterIssuer and a Certificate). Helm values are stored separately under `helm/external-values/`. |

Application, project, and values conventions are documented in [Setup conventions](#setup-conventions) below and in [CODING-STANDARD.md](CODING-STANDARD.md).

Folder names organize the repository; each manifest's project and destination fields determine its ArgoCD permissions and deployment target. A purpose folder is synchronized only when a parent Application references it or its manifests are applied separately.

## Local components

| Directory | Components and pinned chart versions | AppProject | Target namespaces | Registered by `sync-all-groups.yaml` |
| --- | --- | --- | --- | --- |
| [infra](local/infra/README.md) | ArgoCD `10.9.5`; Kargo `1.11.5`; cert-manager `v1.14.4`; Argo Rollouts `2.43.2` | `infra` | `argocd`, `kargo`, `cert-manager`, `kube-system` (leader-election RBAC), `argo-rollouts`, `kargo-cluster-secrets`, `kargo-system-resources`, `kargo-shared-resources` | Yes, as `infra-local` |
| [games-orchestrator](local/games-orchestrator/) | Agones `1.61.0` | `hosting-local` | `agones-system` | Yes, as `games-orchestrator-local` |
| [games](local/games/) | `simple-game-server` using the CouchPartyGames `fleet` chart `1.0.9` | `games` | `default` | Yes, as `games-local` |
| [match-making](local/match-making/) | Open Match `1.8.1`, defined as both an Application and an ApplicationSet; custom `open-match-components` chart `0.0.3` | `matchmaking-local` | `open-match` | No |
| [general](local/general/) | Self-signed ClusterIssuer and allocator certificate; Prometheus `25.18.0` and operator CRDs `10.0.0`; Grafana `7.3.7`; Tempo `1.7.2`; Fluent Bit `0.46.0`; Postfix (`mail` chart) `3.5.1`; MailHog `5.2.2` | Built-in `default` | `agones-system`, `monitoring`, `logging`, `default` | No |

Versions above are the pins in this repository, not a claim that the upstream charts have been rendered or tested together. The allocator certificate creates `allocator-tls` in `agones-system` for `127.0.0.1`, using the `selfsigned` ClusterIssuer, so it needs cert-manager and the Agones namespace.

The `infra` directory also manages ArgoCD itself: its `argo-cd` Application installs chart `10.9.5` as release `argo-cd` in `argocd`, the same release the bootstrap scripts create. Keep its version aligned with `ARGO_CD_CHART_VERSION` in `scripts/versions.sh`.

## How local synchronization works

[local/sync-all-groups.yaml](local/sync-all-groups.yaml) is the app-of-apps entry point. It creates three parent Applications in `argocd`, each reading a directory from Git:

| Parent Application | Source path |
| --- | --- |
| `infra-local` | `argocd/local/infra` |
| `games-local` | `argocd/local/games` |
| `games-orchestrator-local` | `argocd/local/games-orchestrator` |

The parents use the `default` project, track Git `HEAD`, and enable automatic sync with pruning and self-healing. Child Applications with a Git values source track `main` and refer to it as `myRepo`; Helm value paths begin with `$myRepo/`. Changes must be pushed before ArgoCD can reconcile them. Every parent and most children pull this repository over SSH, so ArgoCD needs repository credentials; see [Add the Git repository](../scripts/README.md#add-the-git-repository).

Child sync policies differ:

- `agones-local` has automatic sync commented out, so Agones installs only when synced manually.
- `simple-game-server` syncs automatically, but its Fleet needs the Agones CRDs and fails until Agones is installed.
- The `argo-cd` Application syncs automatically with pruning but without self-healing. Kargo, cert-manager, and Argo Rollouts also self-heal and use server-side apply. See the [infrastructure README](local/infra/README.md) for component roles, the Kargo Secret, and startup dependencies.

The `infra` AppProject has sync wave `-1`, so it is created before its Applications. There is no other sync-wave ordering between prerequisites such as cert-manager CRDs, Agones, and game Fleets. The parents' `default` destination namespace does not override namespaces set in child manifests.

## Local bootstrap

Run from the repository root with a working container runtime, Helm, kubectl, and minikube, kind, or k3s. The [bootstrap scripts](../scripts/README.md) create a cluster and install ArgoCD:

```bash
./scripts/minikube-bootstrap.sh
# Or: ./scripts/kind-bootstrap.sh
```

1. Register this repository's SSH URL in ArgoCD, as described in the [scripts README](../scripts/README.md#add-the-git-repository).
2. Provision the `kargo-api` Secret described in the [infrastructure README](local/infra/README.md#bootstrap-requirements).
3. Register the parent applications and check their status. For minikube:

   ```bash
   kubectl --context multiplayer-demo apply -f argocd/local/sync-all-groups.yaml
   kubectl --context multiplayer-demo -n argocd get applications,applicationsets,appprojects
   ```

   For kind, use `--context kind-multiplayer-demo`.
4. Sync Agones manually, then let `simple-game-server` retry:

   ```bash
   argocd app sync argocd/agones-local
   ```

Applying the entry point creates the parent Applications; child synchronization still depends on valid manifests, allowed repositories, available charts, and prerequisite CRDs. Do not apply `general/` or `match-making/` directly until the naming conflicts below are fixed.

## Review notes: current deployment blockers

These findings come from inspecting the checked-in manifests, parsing them, and checking referenced values paths. No live cluster sync or chart rendering was performed.

| Area | Finding |
| --- | --- |
| Unregistered directories | `sync-all-groups.yaml` has no parent for `match-making/` or `general/`. |
| Duplicate matchmaking application | `components.yaml`, `open-match-app.yaml`, and the ApplicationSet (template `open-match-{{region}}` with region `local`) all produce `open-match-local`. The components application needs a distinct name, and core Open Match needs one owner. |
| Duplicate general names | `general/mailhog.yaml` and `general/tempo.yaml` both name their Application `cert-manager`, with `purpose: certificates` labels. Applying `general/` would overwrite the `infra` `cert-manager` Application. |
| Missing values | `components.yaml` references `helm/external-values/local/open-match-components-local.yaml`, which does not exist. |
| Repository permissions | `matchmaking-local` does not allow `https://couchpartygames.github.io/helm-charts`, the custom components chart repository. |
| Agones sync | Automatic sync is commented out on `agones-local` without the explanatory comment the standard requires, so `simple-game-server` fails until someone syncs Agones. |
| Formatting | `games-orchestrator/project.yaml` has tabs before an inline comment. kubectl accepts it, but strict YAML parsers such as PyYAML reject it, and the coding standard forbids tabs. |
| Standard drift | Values files outside `infra` and `games-orchestrator` still sit directly in `helm/external-values/local/` instead of an area subdirectory. The `games` and `hosting-local` project names predate the `<area>-<env>` rule in [CODING-STANDARD.md](CODING-STANDARD.md). |

## Setup conventions

Each area directory is a self-contained unit made of one AppProject, its Applications, and the values files they read. The rules for writing these files are in [CODING-STANDARD.md](CODING-STANDARD.md).

### AppProject files

Every area except `general/` has exactly one `project.yaml`:

```text
argocd/local/games-orchestrator/project.yaml   # AppProject hosting-local
argocd/local/match-making/project.yaml         # AppProject matchmaking-local
```

An AppProject defines what its Applications may do: `sourceRepos` (chart repositories and this Git repository), `destinations` (cluster and namespaces), and the allowed resource kinds. Its `metadata.name` follows `<area>-<env>`; `infra` is the shared-infrastructure exception, and `games` predates the rule. `general/` uses the built-in `default` project. All current projects allow every cluster- and namespace-scoped resource kind; `hosting-local` also allows any namespace on any cluster, and `games` allows any namespace except `agones-system` and `kube-system`.

### Application files

An Application is one file per component in the area directory. It reads a Helm chart and a values file from this repository using two sources:

```yaml
spec:
  project: hosting-local            # must equal metadata.name in project.yaml
  sources:
  - repoURL: git@github.com:CouchPartyGames/MultiplayerGameService.git
    targetRevision: main
    ref: myRepo                     # exposes this repo as $myRepo
  - repoURL: https://agones.dev/chart/stable
    chart: agones
    targetRevision: 1.61.0          # chart version is pinned here
    helm:
      valueFiles:
      - $myRepo/helm/external-values/local/games-orchestrator/agones-local.yaml
  destination:
    name: in-cluster
    namespace: agones-system
```

The chart repository MUST be in the project's `sourceRepos` and the destination namespace MUST be allowed by its `destinations`. Argo Rollouts, Grafana, Prometheus, and the Open Match ApplicationSet use a single chart source with inline or default values instead.

### Helm values files

Values files live in `helm/external-values/<env>/<area>/` and are named `<app>-<env>.yaml`. Only `infra` and `games-orchestrator` follow this layout so far; older files still sit directly in `helm/external-values/<env>/`:

```text
helm/external-values/
├── local/
│   ├── games-orchestrator/
│   │   └── agones-local.yaml
│   ├── infra/
│   │   ├── argo-cd-local.yaml
│   │   ├── cert-manager-local.yaml
│   │   └── kargo-local.yaml
│   ├── open-match-local.yaml
│   ├── simple-game-local.yaml
│   └── ...
└── prod/
    ├── agones-prod.yaml
    ├── argocd-prod.yaml
    ├── keycloak-prod.yaml
    ├── open-match-prod.yaml
    └── postgresql-prod.yaml
```

Some local values files, such as `keycloak-local.yaml`, `postgresql-local.yaml`, and `ingress-nginx-local.yaml`, are not referenced by any Application. The helper scripts `install-keycloak.sh` and `install-postgresql.sh` remain in `helm/external-values/local/` and should move to `scripts/`.

To add a component: create `<app>.yaml` in the area directory, add its chart repository to `project.yaml`, add `helm/external-values/<env>/<area>/<app>-<env>.yaml`, and reference its full path from `valueFiles`. Then render the chart (see [Editing and validation](#editing-and-validation)).

## Editing and validation

Follow [CODING-STANDARD.md](CODING-STANDARD.md). Keep chart versions and values paths aligned, and ensure every application's `spec.project`, source repositories, and destination match its AppProject. Use two-space YAML indentation and unique Application names within the ArgoCD namespace:

```bash
grep -rh '^  name:' argocd/local --include=*.yaml | sort | uniq -d
```

Store new secrets through the repository's SOPS and age workflow.

Render changed Helm values using the chart version pinned in the relevant manifest:

```bash
helm template <release> <repo>/<chart> \
  --version <targetRevision> \
  -f helm/external-values/<env>/<area>/<app>-<env>.yaml
```

Where a suitable cluster has the required CRDs installed, validate changed manifests before syncing:

```bash
kubectl apply --dry-run=server -f <manifest.yaml>
```

Server validation checks resource schemas; chart rendering and ArgoCD sync status are still needed to verify source access, values compatibility, and application dependencies.
