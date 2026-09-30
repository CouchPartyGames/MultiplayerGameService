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
