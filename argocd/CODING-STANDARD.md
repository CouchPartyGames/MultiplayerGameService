# ArgoCD Coding Standard

Rules for every manifest under `argocd/` and every values file under `helm/external-values/`. [README.md](README.md) explains how the pieces fit together; this file says what new or edited files must look like. Words like MUST and SHOULD follow their usual meaning.

## 1. YAML formatting

- Two-space indentation. Tabs MUST NOT appear anywhere, including in comments and after values.
- Every manifest file starts with `---`. Files holding several documents separate them with `---`.
- List items under a key are indented two spaces beneath it (`sources:` then `  - repoURL: ...`).
- Quote strings that contain `{{ }}`, `*`, `!`, or `:`. Leave other strings unquoted.
- One blank line between top-level sections of `metadata` and `spec`. No trailing whitespace. End files with a newline.
- Comments explain why, not what. Do not leave dead commented-out blocks; delete them (git keeps history).

## 2. File naming

All names are lowercase kebab-case with a `.yaml` extension (never `.yml`).

| Kind | Location | Filename |
| --- | --- | --- |
| AppProject | `argocd/<env>/<area>/` | `project.yaml`, exactly one per area |
| Application | `argocd/<env>/<area>/` | `<app>.yaml`, named for the upstream chart or component (`agones.yaml`, `cert-manager.yaml`) |
| ApplicationSet | `argocd/<env>/<area>/` | `<app>-appset.yaml` |
| Extra Application for the same component | `argocd/<env>/<area>/` | `<app>-<qualifier>.yaml` (`open-match-components.yaml`) |
| Supporting resources (certificates, issuers) | `argocd/<env>/<area>/` | `<kind-or-purpose>.yaml`, lowercase kind (`clusterissuer.yaml`) |
| App-of-apps entry point | `argocd/<env>/` | `sync-all.yaml` |
| Helm values | `helm/external-values/<env>/` | `<app>-<env>.yaml` |
| Area README | `argocd/<env>/<area>/` | `README.md`, only when the area needs more than the root README says |

Existing files that predate this standard (`agones-app.yaml`, `open-match-app.yaml`, `components.yaml`, `simple-game-server.yaml`) SHOULD be renamed when they are next touched.

## 3. AppProjects

- `metadata.name` is `<area>-<env>` (`hosting-local`, `matchmaking-local`, `games-local`). `infra` is the single existing exception because it is shared infrastructure.
- `metadata.namespace: argocd`. Always set the `environment` label.
- `spec.description` states the area and environment.
- `sourceRepos` lists every chart repository and this Git repository, and nothing else. Add the chart repository in the same change that adds an Application using it.
- `destinations` lists explicit namespaces with `name: in-cluster`. Use `'*'` only where the area must host workloads in arbitrary namespaces (game servers) and comment why.
- Keep `resources-finalizer.argocd.argoproj.io` on projects that other Applications reference, so a project cannot be deleted while in use.
- Use `sync-wave: "-1"` on a project when its Applications sync in the same pass, so the project exists first.

## 3a. Repository URL

The Git source is always `git@github.com:CouchPartyGames/MultiplayerGameService.git`, tracking `targetRevision: main`, with `ref: myRepo`.

## 4. Applications

Field order: `metadata`, `spec.project`, `spec.sources`, `spec.destination`, `spec.syncPolicy`, `spec.revisionHistoryLimit`.

- `metadata.name` is `<app>` in a single-environment folder or `<app>-<env>` when the same name could occur in several environments. Names MUST be unique across the whole `argocd` namespace; check with `grep -rh '^  name:' argocd`.
- `metadata.namespace: argocd`. Labels: `environment` (required) and `purpose` (optional).
- `spec.project` MUST equal the `metadata.name` of the area's `project.yaml`.
- Use multi-source: first the Git source (`ref: myRepo`), then the chart source. Pin the chart with an exact `targetRevision` (no ranges, no `latest`, no `*`).
- Values files are listed in `helm.valueFiles` as `$myRepo/helm/external-values/<env>/<app>-<env>.yaml`. Use the full path from the repository root. Do not inline `helm.values` for anything larger than a one-line override.
- `destination` uses `name: in-cluster` and an explicit `namespace`.
- Sync policy defaults:

  ```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 3
  ```

  Deviating from `automated` (for example Agones, which is synced manually) needs a comment stating the reason.
- Set `revisionHistoryLimit: 3`.
- Use sync waves (`argocd.argoproj.io/sync-wave`) when one app needs another's CRDs first.

## 5. ApplicationSets

- Use them only when one component is deployed to several clusters or regions. A single-cluster component uses a plain Application.
- A component MUST be owned by either an Application or an ApplicationSet in a given environment, never both.
- Template expressions (`{{region}}`) MUST be quoted, and the generated Application name MUST include `<env>` and, if applicable, the region.
- Follow section 4 for the template body.

## 6. Helm values files

- Location: `helm/external-values/<env>/`. Environments are `local` and `prod`. Do not place values files directly in `helm/external-values/`.
- Name: `<app>-<env>.yaml`, where `<app>` is the same name as the Application file (`agones-local.yaml`, `open-match-prod.yaml`). Do not use `.values.yaml` or `.yml`, and do not omit the environment suffix.
- One values file per Application. Do not share a file between Applications or between charts, even when two Keycloak charts look alike; give each chart its own file (`keycloak-bitnami-local.yaml`).
- Contain only overrides of chart defaults. Do not copy the entire default `values.yaml`.
- Group related keys and comment non-obvious settings, citing the chart option where useful.
- No plaintext credentials outside local/demo values. Real secrets go through SOPS + age.
- Helper scripts (`install-*.sh`) do not belong here; put them in `scripts/`.
- Chart versions live in the Application's `targetRevision`, never in the values file.

## 7. Changing files

- Renaming or moving a values file MUST update every `$myRepo/helm/external-values/...` reference in the same commit. Check with:

  ```bash
  grep -rn 'myRepo/' argocd | sed 's/.*\$myRepo/helm-path: $myRepo/'
  ```

  and confirm each path exists in the repository.
- Bumping a chart version: update `targetRevision`, then render with `helm template` and the matching values file.
- Validate with `kubectl apply --dry-run=server -f <file>` where the ArgoCD CRDs are available, and check YAML syntax before committing.
- Commit messages use `chore:`, `fix:`, or `feat:` followed by an imperative summary.
