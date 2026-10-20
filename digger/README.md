# Digger

This directory holds draft configuration for [Digger](https://github.com/diggerhq/digger), which runs `terraform plan` and `apply` for the root modules in `terraform/envs/` from pull request comments, in GitHub Actions. None of it is active yet. GitHub runs workflows only from `.github/workflows/`, and Digger reads `digger.yml` only from the repository root, so each file here must be moved before it takes effect.

| File | Moves to | Purpose |
| --- | --- | --- |
| `digger.yml` | `digger.yml` | Projects (root modules) and the steps Digger runs for each |
| `digger-workflow.yml` | `.github/workflows/digger-workflow.yml` | The job the Digger orchestrator dispatches to plan or apply a project |
| `digger-sync-projects.yml` | `.github/workflows/digger-sync-projects.yml` | Daily PR that keeps `digger.yml` in step with `terraform/envs/` |
| `digger-terraform-plan-drift.yml` | `.github/workflows/digger-terraform-plan-drift.yml` | Weekday drift detection, reported to Slack |
| `scripts/digger-missing-projects.sh` | stays here | Adds and removes `digger.yml` projects; used by the sync workflow |
| `.pre-commit-config.yaml`, `.yamllint.yaml`, `.yamlfmt` | stay here | YAML lint and format hooks (see [Pre-commit hooks](#pre-commit-hooks)) |

## `digger.yml`

Each entry under `projects` is a root module that Digger plans and applies on its own. A project has a `name`, a `dir` relative to the repository root, a `workflow`, and an optional `depends_on` list of projects to apply first. The two workflows are:

- `default`: `init` then `plan`; `apply`.
- `prod`: the same, plus a `checkov` scan before `plan`. It plans when a PR is pushed and unlocks when the PR closes or merges to the default branch.

The projects in the file are examples whose `infra/...` directories don't exist in this repository. The first sync PR replaces them with the real envs (see [Keeping projects in sync](#keeping-projects-in-sync)).

## `digger-workflow.yml`

The Digger orchestrator, either the hosted GitHub App or a self-hosted one, starts this workflow with `workflow_dispatch` and a `spec` input that names the project and command. The job assumes an AWS role through OIDC, so it needs no static keys.

Before enabling it:

- Install the Digger GitHub App, or run your own orchestrator.
- Add the `AWS_ROLE_TO_ASSUME` repository secret.
- Replace `diggerhq/digger@vLatest` with a release tag.
- Set `terraform-version` to match `TERRAFORM_VERSION` in `terraform/tools/version.sh`.

The job sets up AWS credentials only. Projects in `envs/azure-*` and `envs/gcp-*` need their own credentials before Digger can plan them.

## Keeping projects in sync

`digger-sync-projects.yml` runs every day at 06:00 UTC and can also be started by hand. It runs `scripts/digger-missing-projects.sh`, then opens a pull request on the `chore/digger-sync-projects` branch with the changes, for someone to review and merge. Later runs update the same PR. If `digger.yml` gets back in sync before the PR merges, the workflow deletes the branch, which closes the PR.

The script compares `digger.yml` with `terraform/envs/`:

- Each env directory that contains `.tf` files and has no project gets a new project. The project is named after the directory and uses the `default` workflow; change `workflow` or add `depends_on` in the PR if the env needs them.
- Each project whose `dir` has no `.tf` files is removed, along with any `depends_on` entries that name it.
- Root modules in `terraform/bootstrap/` are left out, because they are applied by hand.

The script needs [yq](https://github.com/mikefarah/yq) v4, which GitHub's `ubuntu-latest` runners already include. To preview the changes locally without editing anything, run from the repository root:

```bash
./digger/scripts/digger-missing-projects.sh --check
```

It prints one Markdown line per change and exits 1 when changes are needed. Without `--check`, it edits the config in place. Pass a path to use a config other than `digger/digger.yml`:

```bash
./digger/scripts/digger-missing-projects.sh digger.yml
```

yq removes blank lines and comment padding when it rewrites the file, so the first sync reformats `digger.yml`. Later syncs change only the projects.

Before enabling the workflow:

- Under Settings > Actions > General, turn on "Allow GitHub Actions to create and approve pull requests".
- When `digger.yml` moves to the repository root, change `DIGGER_CONFIG` at the top of the workflow.

Pull requests opened with `GITHUB_TOKEN` don't trigger other workflows, so CI doesn't run on the sync PR.

## Drift detection

`digger-terraform-plan-drift.yml` runs Digger in `drift-detection` mode at 06:00 UTC on weekdays and posts drift to the Slack webhook in the `DRIFT_SLACK_WEBHOOK` secret. It is incomplete; before enabling it:

- Add a workflow `name`, and `runs-on: ubuntu-latest` to the `drift` job; GitHub rejects a job without `runs-on`.
- Replace `<release-tag>` with a Digger release.
- Add `permissions` and cloud credentials so it can run `terraform plan`, as `digger-workflow.yml` does.
- Add the `DRIFT_SLACK_WEBHOOK` repository secret.

## Pre-commit hooks

`.pre-commit-config.yaml` checks every `.yml` and `.yaml` file in this directory on commit. [prek](https://github.com/j178/prek) runs it in workspace mode from `digger/` (see `tools/README.md`):

| Hook | Check | Config |
| --- | --- | --- |
| `yamllint` | Syntax and style: two-space indentation, no trailing spaces, valid truthy values | `.yamllint.yaml` |
| `yamlfmt` | Fails when a file differs from yamlfmt's output, and prints the diff | `.yamlfmt` |

The yamlfmt hook calls the local binary, so install it first with `./tools/yamlfmt-install.sh`. To fix formatting, run `yamlfmt` from `digger/`. yamlfmt puts one space before an inline comment, so don't align comments in columns.

Run only these hooks from the repository root:

```bash
prek run digger/ --all-files
```

`--all-files` covers only files Git tracks. Before the first commit, pass the files with `prek run --files digger/*.yml` instead.

`.yamllint.yaml` differs from the root config used for `argocd/` in two ways: it doesn't require `---` at the top of a file, because GitHub workflows and `digger.yml` don't use one, and it allows one space before inline comments, which is what yamlfmt and the sync script's `yq` write.
