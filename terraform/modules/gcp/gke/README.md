# GCP network and GKE

This child module creates infrastructure in an existing GCP project:

- A custom VPC and regional subnet with separate node, Pod, and Service ranges.
- A zonal GKE Standard cluster on the `REGULAR` release channel.
- A separately managed node pool (three `e2-standard-4` nodes by default), with automatic repair and upgrades.
- A dedicated node service account and Workload Identity Federation for workloads.
- An optional inbound UDP rule for Agones ports `7000-8000`.

Nodes have public IPs so Agones can advertise directly reachable game servers. The Kubernetes API uses a public endpoint restricted to `admin_cidrs`. The optional game firewall only targets this cluster's nodes. GKE manages its own cluster communication firewall rules. No Cloud NAT is needed for these public nodes.

The module has no `provider` block. The calling root module configures the Google provider and passes the same `project_id`, `region`, and `zone`. [`terraform/envs/gcp-multiplayer-demo/`](../../../envs/gcp-multiplayer-demo/) calls it.

## Usage

```hcl
module "gke" {
  source = "../../modules/gcp/gke"

  project_id  = "multiplayer-demo"
  region      = "us-east1"
  zone        = "us-east1-b"
  admin_cidrs = ["203.0.113.10/32"]
}
```

Inputs are in [`variables.tf`](variables.tf) and outputs in [`outputs.tf`](outputs.tf). Only `project_id` and `admin_cidrs` are required.

This is a single-zone demo baseline. A production availability design should consider a regional cluster and nodes across zones. Kubernetes components, including ArgoCD and Agones, are installed separately; the manifests under `argocd/prod/` are still skeletons and need their cluster destinations configured.

## Prerequisites

- Terraform 1.5 or later, below 2.0, Google Cloud CLI, `kubectl`, and the GKE authentication plugin (`gke-gcloud-auth-plugin`).
- An existing project with billing enabled and sufficient Compute Engine quota for the nodes and temporary upgrade capacity.
- An authenticated identity permitted to enable APIs, manage networks and GKE clusters, create service accounts, update project IAM, and act as the node service account. Typical roles are Service Usage Admin, Compute Network Admin, Compute Security Admin, Kubernetes Engine Admin, Service Account Admin, Service Account User, and Project IAM Admin, scoped to the target project.
- Service Usage API enabled as a bootstrap prerequisite. Terraform enables the remaining required APIs and retains them on destroy.

## Deploy

From the root module, `terraform/envs/gcp-multiplayer-demo/`:

```bash
gcloud auth login
gcloud auth application-default login
gcloud services enable serviceusage.googleapis.com --project YOUR_PROJECT_ID
cp terraform.tfvars.example terraform.tfvars
```

In `main.tf`, set `project_id` in `locals`. If changing the location, set both `region` and a `zone` within that region. Edit `terraform.tfvars`: replace the documentation-only administrator IP with your workstation or VPN's public IPv4 address followed by `/32`. CIDR ranges must not overlap each other or networks you intend to connect. Pass `enable_agones_udp = true` to the module when deploying game servers that use the default Agones UDP range; adjust `game_client_cidrs` if access should be restricted.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
terraform output -raw get_credentials_command
```

Run the printed `gcloud container clusters get-credentials` command, then:

```bash
kubectl get nodes
```

The node account has the [GKE node role](https://docs.cloud.google.com/kubernetes-engine/security/configure-node-service-accounts). To pull private Artifact Registry images, grant it `roles/artifactregistry.reader` on the relevant repository separately. Workloads needing Google APIs require their own Workload Identity IAM bindings.

## State and credentials

Authentication uses Application Default Credentials; no service account keys are stored in these files. Terraform uses local state by default. State, variable values, saved plans, and downloaded providers are ignored by Git; keep the generated `.terraform.lock.hcl` in version control. Use the repository's SOPS and age workflow for any new secrets.

For shared use, add a GCS backend to the root module with a separately provisioned state bucket and run `terraform init -migrate-state` before collaborating. Keep state secure and backed up because it is required to manage or destroy the resources.

## Destroy

First remove Kubernetes Services of type LoadBalancer and workloads with provisioned disks if their cloud resources should also be deleted. Then pass `deletion_protection = false` to the module in the root module's `main.tf` and apply that change before destroying:

```bash
terraform apply
terraform destroy
```

The separate apply is required by the [Google provider's cluster deletion protection](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster). The GCP project and enabled APIs are retained.
