# Terraform

This directory contains Terraform and Atlantis installation scripts in `scripts/` and separate GCP/GKE, Azure/AKS, and AWS/EKS configurations. Run the commands below from the repository root.

## Install Terraform

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/scripts/terraform-install.sh
```

The script downloads Terraform from HashiCorp, checks the archive against its SHA-256 checksum, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `TERRAFORM_VERSION` in `scripts/version.sh`; override it for one run with:

```bash
TERRAFORM_VERSION=1.16.4 ./terraform/scripts/terraform-install.sh
```

Check the installed version with `terraform version`.

## Install Atlantis

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/scripts/atlantis-install.sh
```

The script downloads Atlantis from its GitHub releases, checks the archive against the release's SHA-256 checksums, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `ATLANTIS_VERSION` in `scripts/version.sh`; override it for one run with:

```bash
ATLANTIS_VERSION=0.48.1 ./terraform/scripts/atlantis-install.sh
```

## Install TFLint

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/scripts/tflint-install.sh
```

The script downloads TFLint from its GitHub releases, checks the archive against the release's SHA-256 checksums, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `TFLINT_VERSION` in `scripts/version.sh`, which matches the `tflint_version` in `.github/workflows/terraform.yaml`; keep the two in step. Override it for one run with:

```bash
TFLINT_VERSION=0.64.0 ./terraform/scripts/tflint-install.sh
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
   tflint --chdir=terraform/aws --config="$PWD/.tflint.hcl" --format=compact
   ```

   Replace `terraform/aws` with `terraform/azure` or `terraform/gcp` for the others.

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

The `tflint` job in `.github/workflows/terraform.yaml` lints `terraform/aws`, `terraform/azure`, and `terraform/gcp` on every pull request and push to `main` that touches `terraform/` or `.tflint.hcl`. A finding fails the job. The `terraform_tflint` pre-commit hook runs the same check on commit (see [Pre-commit hooks](#pre-commit-hooks)).

The config does not yet include the provider rulesets (`tflint-ruleset-aws`, `tflint-ruleset-azurerm`, `tflint-ruleset-google`), which check things like invalid instance types and regions. To add one, add a `plugin` block with its `source` and `version` to `.tflint.hcl` and run `tflint --init` again. CI passes `GITHUB_TOKEN` to `tflint --init` so plugin downloads from GitHub are not rate-limited.

## Unit tests

Each configuration has unit tests in `<cloud>/tests/unit.tftest.hcl`, run by Terraform's native test framework. They use mock providers, so they need no cloud credentials and create no resources. Each `run` block plans the configuration and checks derived values, such as subnet ranges, the AKS DNS address, and the optional Agones firewall rule. Other runs pass bad inputs and expect the variable validations to reject them.

Run one configuration's tests from the repository root:

```bash
terraform -chdir=terraform/aws init -backend=false
terraform -chdir=terraform/aws test
```

Or run every configuration's tests, initializing any that need it:

```bash
./terraform/scripts/terraform-test.sh
```

When you change a variable validation or the logic behind a derived value, add or update the matching `run` block.

## Pre-commit hooks

`.pre-commit-config.yaml` runs four hooks on commits that touch `terraform/`, each in the directories with changed files:

| Hook | Check |
|------|-------|
| `terraform_tflint` | TFLint with the shared `.tflint.hcl` |
| `terraform_fmt` | `terraform fmt -check -diff`; fails on unformatted `.tf` or `.tftest.hcl` files. Run `terraform fmt -recursive terraform` to fix them. |
| `terraform_validate` | `terraform init -backend=false` when needed, then `terraform validate` |
| `terraform-test` | `terraform test` via `scripts/terraform-test.sh` |

Install Terraform and TFLint with the scripts above, then install the hooks once per clone with `pre-commit install`. To run them without committing:

```bash
pre-commit run --files $(git ls-files terraform)
```

## Terraform skill for AI agents

The repository includes Anton Babenko's [terraform-skill](https://github.com/antonbabenko/terraform-skill), an agent skill with Terraform and OpenTofu guidance for writing, reviewing, and debugging modules, tests, CI, security scans, and state operations. The skill files live in `.agents/skills/terraform-skill/`, `.claude/skills/terraform-skill` links to them for Claude Code, and `skills-lock.json` records the source and content hash.

Claude Code loads the skill automatically when a task involves Terraform. You can also invoke it directly with `/terraform-skill`. With the skill loaded, the agent states its version and backend assumptions, names the risk it addresses, gives validation commands such as `terraform fmt -check`, `terraform validate`, and `terraform plan -out`, and includes rollback notes for state-changing work. It will not run `terraform destroy` until it has shown a `terraform plan -destroy` and received confirmation.

To install the skill in another checkout or update it to the latest release, run:

```bash
npx skills add antonbabenko/terraform-skill
```

## GCP configuration

`gcp/` defines a single-zone GKE cluster, its VPC and subnet, a node service account, and an optional Agones UDP firewall rule. It requires Terraform 1.5 through 1.x and Google provider 7.x. Before planning, authenticate to GCP and provide a project with billing enabled and the permissions needed to create these resources.

```bash
cp terraform/gcp/terraform.tfvars.example terraform/gcp/terraform.tfvars
# Edit project_id and admin_cidrs in terraform/gcp/terraform.tfvars.
terraform -chdir=terraform/gcp init
terraform -chdir=terraform/gcp plan
```

Review the plan and estimated GCP costs before applying it. The cluster has deletion protection enabled by default.

## Azure configuration

`azure/` defines a virtual network, subnet, managed cluster identity, and AKS cluster. It requires Terraform 1.5 through 1.x and AzureRM provider 4.x. See the [Azure setup](azure/README.md) for permissions, networking defaults, and deployment instructions.

```bash
az login
cp terraform/azure/terraform.tfvars.example terraform/azure/terraform.tfvars
# Edit subscription_id, admin_cidrs, and admin_group_object_ids.
terraform -chdir=terraform/azure init
terraform -chdir=terraform/azure plan
```

## AWS configuration

`aws/` defines a VPC with public/private subnets across two zones, NAT routing, IAM roles, and an EKS cluster with managed nodes. It requires Terraform 1.5 through 1.x and AWS provider 6.x. See the [AWS setup](aws/README.md) for authentication, administrator access, and deployment instructions.

```bash
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars
# Edit admin_cidrs and admin_principal_arns; authenticate with your AWS profile.
terraform -chdir=terraform/aws init
terraform -chdir=terraform/aws plan
```
