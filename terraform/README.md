# Terraform

This directory contains Terraform and Atlantis installers in `tools/`, the `terraform test` runner in `scripts/`, provider bootstrap root modules in `bootstrap/`, and GCP/GKE, Azure/AKS, and AWS/EKS cluster configurations split into root modules in `envs/` and child modules in `modules/`. Run the commands below from the repository root.

## Root and child modules

New Terraform code is split into root modules, which you run, and child modules, which root modules call:

```text
terraform/
├── bootstrap/                     # root modules that prepare a provider (see Bootstrap)
│   └── <cloud-provider>/          # aws, azure, or gcp
│       └── <module-name>/         # e.g. aws/aws-state-bucket
├── envs/                          # root modules: one per cloud account
│   └── <cloud>-<accountid>/       # e.g. aws-123456789012
└── modules/                       # child modules: reusable, never run directly
    └── <cloud-provider>/          # aws, azure, or gcp
        └── <module-name>/         # e.g. aws/s3-terraform-state
```

### Root modules: `envs/<cloud>-<accountid>/`

A root module is a directory you run `terraform init`, `plan`, and `apply` in, and it has its own state. Each one manages a single cloud account, so a bad apply cannot reach another account. Name the directory after the cloud and its account identifier:

| Cloud | `<accountid>` | Example |
| --- | --- | --- |
| AWS | 12-digit account ID | `envs/aws-123456789012/` |
| Azure | Subscription ID | `envs/azure-00000000-0000-0000-0000-000000000000/` |
| GCP | Project ID | `envs/gcp-multiplayer-demo/` |

A root module holds everything specific to its account:

- The `backend` block that says where its state lives.
- The `provider` blocks, with the region and account or project they target.
- Variable values. Commit a `terraform.tfvars.example`; `.gitignore` keeps the real `*.tfvars` out of Git.
- `module` blocks that call child modules, plus any resources too specific to reuse.
- Its `.terraform.lock.hcl`, committed so every run uses the same provider builds.

Run a root module from the repository root:

```bash
terraform -chdir=terraform/envs/aws-123456789012 init
terraform -chdir=terraform/envs/aws-123456789012 plan -out=tfplan
```

### Child modules: `modules/<cloud-provider>/<module-name>/`

A child module is a reusable group of resources, such as `modules/aws/s3-terraform-state/`, which creates the bucket and lock table for an S3 state backend. It has no state of its own: its resources live in the state of each root module that calls it. Group modules by provider, using `aws`, `azure`, or `gcp`.

Write child modules so any root module can call them:

- Do not add `provider` or `backend` blocks. The calling root module configures both, and a module with its own `provider` block cannot be used with `count` or `for_each`.
- Declare `required_version` and `required_providers` in `versions.tf`. Use a lower bound and a major-version limit, such as `~> 6.0`, so the root module can pick the exact version. TFLint fails a module without them.
- Give every variable a `description` and `type`, and add `validation` where a bad value would otherwise fail during apply. Give every output a `description`.
- Take account-specific values, such as names, regions, and KMS keys, as variables instead of hard-coding them.
- Add a `README.md` with inputs, outputs, and a usage example, and unit tests in `tests/unit.tftest.hcl` that use a mock provider.

Call a child module from a root module with a relative path:

```hcl
module "terraform_state" {
  source = "../../modules/aws/s3-terraform-state"

  bucket_name = "multiplayer-demo-tfstate-123456789012"
}
```

After changing a child module, run `plan` in every root module that calls it, because the change applies to all of them.

### Current root and child modules

| Root module | Calls |
| --- | --- |
| `envs/aws-123456789012/` | `modules/aws/eks/` |
| `envs/azure-00000000-0000-0000-0000-000000000000/` | `modules/azure/aks/` |
| `envs/gcp-multiplayer-demo/` | `modules/gcp/gke/` |

`modules/aws/s3-terraform-state/` is not called yet. The account IDs in the root module names are placeholders: rename the directory and replace the ID inside it, then update the matching paths in `atlantis.yaml` and `.github/workflows/terraform.yaml`.

### Checks for the new directories

The hooks in `terraform/.pre-commit-config.yaml` lint, validate, and test changed files under `envs/` and `modules/`. A new root module also needs a `README.md` from `envs/README.template.md` (see [Environment docs](#environment-docs)). The `validate` and `tflint` jobs in `.github/workflows/terraform.yaml` list each root and child module, so add new ones to both matrices. `./terraform/scripts/terraform-test.sh` with no arguments tests every child module.

## Bootstrap

`bootstrap/` holds root modules that prepare a cloud provider (AWS, GCP, or Azure) so the root modules in `envs/` can run. A bootstrap module is typically responsible for:

- **Authentication:** the identities that CI and Atlantis use to reach the account, such as an AWS IAM OIDC provider and roles that GitHub Actions can assume.
- **State storage:** the bucket, and lock table where the backend needs one, that holds Terraform state for the `envs/` root modules. Their `backend` blocks point at it.

Group bootstrap modules by provider in `bootstrap/<cloud-provider>/<module-name>/`, for example `bootstrap/aws/aws-state-bucket/`, `bootstrap/gcp/gcp-state-bucket/`, and `bootstrap/azure/azure-state-bucket/`. They follow the same rules as other root modules: they configure their own `provider` blocks, call child modules from `modules/` (the AWS state bucket is the natural caller of `modules/aws/s3-terraform-state/`), and commit their `.terraform.lock.hcl`.

They differ from `envs/` in how they run:

- **They run first, by hand.** Bootstrap creates the credentials and state storage that Atlantis and CI rely on, so it is not an Atlantis project or a CI matrix entry. Apply it with your own administrator credentials, once per account, and again only when the bootstrap resources change.
- **They start with local state.** The state bucket does not exist until the first apply, so a state-bucket module begins without a `backend` block. After the first apply, add a `backend` block that points at the bucket it created and move its state there:

  ```bash
  terraform -chdir=terraform/bootstrap/aws/aws-state-bucket init
  terraform -chdir=terraform/bootstrap/aws/aws-state-bucket apply
  # Add a backend block for the new bucket, then:
  terraform -chdir=terraform/bootstrap/aws/aws-state-bucket init -migrate-state
  ```

  `.gitignore` keeps the local `terraform.tfstate` out of Git. Delete it once the state is migrated.
- **Destroying them breaks every env.** Deleting the state bucket or the CI roles cuts off every root module in that account, so protect them, for example with `prevent_destroy` or bucket deletion protection.

`bootstrap/aws/aws-github-oidc/` creates the GitHub Actions OIDC provider, an IAM role workflows assume, and the role's inline policy; see its [README](bootstrap/aws/aws-github-oidc/README.md). `bootstrap/gcp/gcp-state-bucket/` creates the GCS bucket for the `gcs` backend, which locks state natively; see its [README](bootstrap/gcp/gcp-state-bucket/README.md). The Azure directory has no configuration yet.

## Install Terraform

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/tools/terraform-install.sh
```

The script downloads Terraform from HashiCorp, checks the archive against its SHA-256 checksum, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `TERRAFORM_VERSION` in `tools/version.sh`; override it for one run with:

```bash
TERRAFORM_VERSION=1.16.4 ./terraform/tools/terraform-install.sh
```

Check the installed version with `terraform version`.

## Install Atlantis

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/tools/atlantis-install.sh
```

The script downloads Atlantis from its GitHub releases, checks the archive against the release's SHA-256 checksums, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `ATLANTIS_VERSION` in `tools/version.sh`; override it for one run with:

```bash
ATLANTIS_VERSION=0.48.1 ./terraform/tools/atlantis-install.sh
```

## Install TFLint

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/tools/tflint-install.sh
```

The script downloads TFLint from its GitHub releases, checks the archive against the release's SHA-256 checksums, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `TFLINT_VERSION` in `tools/version.sh`, which matches the `tflint_version` in `.github/workflows/terraform.yaml`; keep the two in step. Override it for one run with:

```bash
TFLINT_VERSION=0.64.0 ./terraform/tools/tflint-install.sh
```

## Lint with TFLint

TFLint catches problems that `terraform validate` does not, such as unused variables and outputs, deprecated syntax, missing `required_providers` version constraints, and naming issues. The shared config is `.tflint.hcl` at the repository root. It enables the bundled `terraform` ruleset with the `recommended` preset, and the AWS, Azure, and GCP configurations all use it.

Run these commands from the repository root. Pass the config as an absolute path: TFLint resolves `--config` relative to the directory it lints, so a relative path breaks with `--chdir`.

1. Install the plugins the config lists. Run this once, and again after you change the `plugin` blocks in `.tflint.hcl`:

   ```bash
   tflint --init --config="$PWD/.tflint.hcl"
   ```

2. Lint one configuration, the same way CI does:

   ```bash
   tflint --chdir=terraform/envs/aws-123456789012 --config="$PWD/.tflint.hcl" --format=compact
   ```

   Replace the path with any other directory under `terraform/envs/` or `terraform/modules/`.

3. Or lint every configuration in one run:

   ```bash
   tflint --recursive --config="$PWD/.tflint.hcl" --format=compact
   ```

TFLint exits non-zero when it finds an issue and prints each one as `file:line:col: severity - message (rule_name)`. To fix it:

- Correct the code. Some rules can fix themselves: add `--fix` to the command to apply those changes, then review the diff.
- If the finding is a false positive, silence that one line with a comment on the line above it, naming the rule:

  ```hcl
  # tflint-ignore: terraform_unused_declarations
  variable "reserved_for_later" {
    type = string
  }
  ```

- To turn a rule off everywhere, add a `rule` block to `.tflint.hcl`, for example `rule "terraform_unused_declarations" { enabled = false }`. This affects every configuration, so prefer a line-level ignore.

The `tflint` job in `.github/workflows/terraform.yaml` lints each root and child module on every pull request and push to `main` that touches `terraform/` or `.tflint.hcl`. A finding fails the job. The `terraform_tflint` pre-commit hook runs the same check on commit (see [Pre-commit hooks](#pre-commit-hooks)).

The config does not yet include the provider rulesets (`tflint-ruleset-aws`, `tflint-ruleset-azurerm`, `tflint-ruleset-google`), which check things like invalid instance types and regions. To add one, add a `plugin` block with its `source` and `version` to `.tflint.hcl` and run `tflint --init` again. CI passes `GITHUB_TOKEN` to `tflint --init` so plugin downloads from GitHub are not rate-limited.

## Unit tests

Each child module has unit tests in `modules/<cloud-provider>/<module-name>/tests/unit.tftest.hcl`, run by Terraform's native test framework. They use mock providers, so they need no cloud credentials and create no resources. Each `run` block plans the module and checks derived values, such as subnet ranges, the AKS DNS address, and the optional Agones firewall rule. Other runs pass bad inputs and expect the variable validations to reject them.

Run one module's tests from the repository root:

```bash
terraform -chdir=terraform/modules/aws/eks init -backend=false
terraform -chdir=terraform/modules/aws/eks test
```

Or run every module's tests, initializing any that need it:

```bash
./terraform/scripts/terraform-test.sh
```

When you change a variable validation or the logic behind a derived value, add or update the matching `run` block.

## Pre-commit hooks

`terraform/.pre-commit-config.yaml` runs five hooks on commits that touch `terraform/`, each in the directories with changed files. [prek](https://github.com/j178/prek) runs them in workspace mode, together with the root `.pre-commit-config.yaml`, from the `terraform/` directory, so their `files` patterns and the paths they receive are relative to `terraform/`. Plain pre-commit reads only the root config and skips these hooks, so use prek (see `tools/README.md`).

| Hook | Check |
|------|-------|
| `terraform_tflint` | TFLint with the shared `.tflint.hcl` |
| `terraform_fmt` | `terraform fmt -check -diff`; fails on unformatted `.tf` or `.tftest.hcl` files. Run `terraform fmt -recursive terraform` to fix them. |
| `terraform_validate` | `terraform init -backend=false` when needed, then `terraform validate` |
| `terraform-test` | `terraform test` via `scripts/terraform-test.sh` |
| `env-docs-check` | Env README structure, and a new changelog entry for each env whose configuration changed, via `scripts/env-docs-check.sh` (see [Environment docs](#environment-docs)) |

Install Terraform and TFLint with the scripts above, install prek with `./tools/prek-install.sh`, then install the hooks once per clone from the repository root with `prek install`. To run only the Terraform hooks without committing:

```bash
prek run terraform/ --all-files
```

To skip them for one commit, run `PREK_SKIP=terraform/ git commit`.

## Environment docs

Each root module has a `README.md` in `envs/<cloud>-<accountid>/` with four sections, defined by [`envs/README.template.md`](envs/README.template.md): Purpose, Cloud Provider Details (account, region, and VPC), a Mermaid Diagram, and Most Recent Changes. A changelog line looks like `10/16/2026 - Updated node instance type (#42 - Jete)`, newest first.

Any change to an env's `.tf`, `.tfvars`, or `.hcl` files, or to a child module it calls, needs a new changelog line in that env's README. Test-only changes under `tests/` don't. `scripts/env-docs-check.sh` enforces the template and the new line:

- The `env-docs-check` prek hook checks staged changes. `#TBD` is allowed while the PR doesn't exist yet.
- The `env-docs` job in `.github/workflows/terraform.yaml` checks each pull request against its base branch. Every new line must use the PR's number.

To list the envs that a set of files affects, run `./terraform/scripts/env-docs-check.sh --list-affected <files>`.

AI agents follow the `terraform-env-docs` skill (`.agents/skills/terraform-env-docs/`). It fills in values from the configuration, writes the entry with `#TBD`, opens the PR, and then pushes a commit that replaces `#TBD` with the PR number. Until that commit lands, the first CI run on the PR fails. Set `TF_DOCS_AUTHOR` to choose the author name; it defaults to `git config user.name`.

## Terraform skill for AI agents

The repository includes Anton Babenko's [terraform-skill](https://github.com/antonbabenko/terraform-skill), an agent skill with Terraform and OpenTofu guidance for writing, reviewing, and debugging modules, tests, CI, security scans, and state operations. The skill files live in `.agents/skills/terraform-skill/`, `.claude/skills/terraform-skill` links to them for Claude Code, and `skills-lock.json` records the source and content hash.

Claude Code loads the skill automatically when a task involves Terraform. You can also invoke it directly with `/terraform-skill`. With the skill loaded, the agent states its version and backend assumptions, names the risk it addresses, gives validation commands such as `terraform fmt -check`, `terraform validate`, and `terraform plan -out`, and includes rollback notes for state-changing work. It will not run `terraform destroy` until it has shown a `terraform plan -destroy` and received confirmation.

To install the skill in another checkout or update it to the latest release, run:

```bash
npx skills add antonbabenko/terraform-skill
```

## GCP configuration

`envs/gcp-multiplayer-demo/` calls `modules/gcp/gke/`, which defines a single-zone GKE cluster, its VPC and subnet, a node service account, and an optional Agones UDP firewall rule. It requires Terraform 1.5 through 1.x and Google provider 7.x. Before planning, authenticate to GCP and provide a project with billing enabled and the permissions needed to create these resources.

```bash
cp terraform/envs/gcp-multiplayer-demo/terraform.tfvars.example terraform/envs/gcp-multiplayer-demo/terraform.tfvars
# Set project_id in terraform/envs/gcp-multiplayer-demo/main.tf and admin_cidrs in terraform.tfvars.
terraform -chdir=terraform/envs/gcp-multiplayer-demo init
terraform -chdir=terraform/envs/gcp-multiplayer-demo plan
```

Review the plan and estimated GCP costs before applying it. See the [GCP setup](modules/gcp/gke/README.md) for permissions and deployment instructions. The cluster has deletion protection enabled by default.

## Azure configuration

`envs/azure-00000000-0000-0000-0000-000000000000/` calls `modules/azure/aks/`, which defines a virtual network, subnet, managed cluster identity, and AKS cluster. It requires Terraform 1.5 through 1.x and AzureRM provider 4.x. See the [Azure setup](modules/azure/aks/README.md) for permissions, networking defaults, and deployment instructions.

```bash
az login
cp terraform/envs/azure-00000000-0000-0000-0000-000000000000/terraform.tfvars.example terraform/envs/azure-00000000-0000-0000-0000-000000000000/terraform.tfvars
# Set subscription_id in versions.tf, and admin_cidrs and admin_group_object_ids in terraform.tfvars.
terraform -chdir=terraform/envs/azure-00000000-0000-0000-0000-000000000000 init
terraform -chdir=terraform/envs/azure-00000000-0000-0000-0000-000000000000 plan
```

## AWS configuration

`envs/aws-123456789012/` calls `modules/aws/eks/`, which defines a VPC with public/private subnets across two zones, NAT routing, IAM roles, and an EKS cluster with managed nodes. It requires Terraform 1.5 through 1.x and AWS provider 6.x. See the [AWS setup](modules/aws/eks/README.md) for authentication, administrator access, and deployment instructions.

```bash
cp terraform/envs/aws-123456789012/terraform.tfvars.example terraform/envs/aws-123456789012/terraform.tfvars
# Set the account ID and region in versions.tf, and admin_cidrs and admin_principal_arns in terraform.tfvars.
terraform -chdir=terraform/envs/aws-123456789012 init
terraform -chdir=terraform/envs/aws-123456789012 plan
```
