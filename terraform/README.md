# Terraform

This directory contains Terraform installation scripts and separate GCP/GKE, Azure/AKS, and AWS/EKS configurations. Run the commands below from the repository root.

## Install Terraform

On Linux (amd64 or arm64), install `curl`, `unzip`, and `sha256sum`, then run:

```bash
./terraform/terraform-install-linux.sh
```

The Linux script downloads Terraform from HashiCorp, checks the archive against its SHA-256 checksum, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory.

On macOS, install Homebrew first, then run:

```bash
./terraform/terraform-install-mac.sh
```

The macOS script installs Terraform from the official HashiCorp Homebrew tap. Both installers source `version.sh`. Its `TERRAFORM_VERSION` default controls the Linux download; Homebrew selects the macOS formula version. Override the Linux version for one run with:

```bash
TERRAFORM_VERSION=1.16.4 ./terraform/terraform-install-linux.sh
```

Check the installed version with `terraform version`.

## Install Atlantis

On macOS or Linux (amd64 or arm64), install `curl` and `unzip`, then run:

```bash
./terraform/atlantis-install.sh
```

The script downloads Atlantis from its GitHub releases, checks the archive against the release's SHA-256 checksums, and installs the binary in `/usr/local/bin`. It uses `sudo` if that directory is not writable. Set `INSTALL_DIR` to choose another existing directory. The version comes from `ATLANTIS_VERSION` in `version.sh`; override it for one run with:

```bash
ATLANTIS_VERSION=0.48.1 ./terraform/atlantis-install.sh
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
