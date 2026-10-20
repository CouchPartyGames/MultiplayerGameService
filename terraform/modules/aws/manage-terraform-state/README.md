# AWS network and EKS

This Terraform root creates a VPC, two public and two private subnets across two availability zones, an internet gateway, NAT routing, an EKS cluster, and a managed node group in an existing AWS account.

Defaults are `us-east-1`, three on-demand `m6i.xlarge` Amazon Linux 2023 nodes with 50 GB disks, and one NAT gateway. The first two available standard zones, sorted by name, are selected. Nodes have private IPs and use the private Kubernetes API endpoint. The public API endpoint is restricted to `admin_cidrs`. EKS manages the cluster security group used by the control plane and managed nodes.

The demo shares one NAT gateway between zones. This incurs cross-zone traffic charges and makes outbound connectivity depend on its zone. Set `single_nat_gateway = false` for a NAT gateway in each zone. EKS, EC2, storage, NAT, public IPv4, and logs incur charges.

## Prerequisites

- Terraform 1.5 through 1.x, AWS CLI v2, and `kubectl`.
- An AWS account with quota for the nodes, upgrade capacity, NAT gateways, and Elastic IPs.
- Credentials permitted to manage VPC resources, EKS clusters/node groups/add-ons/access entries, IAM roles and policy attachments (including `iam:PassRole` and service-linked role creation when needed), and CloudWatch log groups.
- At least one existing IAM role or user to administer Kubernetes. Supply its IAM ARN, not an STS assumed-role session ARN. The Terraform caller is not automatically a Kubernetes administrator.

## Deploy

Authenticate using your normal AWS credential chain, for example an AWS CLI SSO profile. From this directory:

```bash
aws sso login --profile YOUR_PROFILE
export AWS_PROFILE=YOUR_PROFILE
aws sts get-caller-identity
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: replace the administrator ARN and documentation-only CIDR with real values. Include the IAM role you will use for `kubectl` in `admin_principal_arns`. That identity also needs `eks:DescribeCluster` to download connection settings; an EKS access policy grants Kubernetes access, not AWS API permissions.

The VPC must be an IPv4 `/16`; public `/20` subnets use indexes 0 and 1 and private `/20` subnets use indexes 8 and 9. Pods use private subnet addresses through the VPC CNI. Avoid overlap with connected networks. EKS chooses its Service range by default.

Set `kubernetes_version` to a minor version supported in your region when explicit version control is needed. With `null`, EKS selects its default at creation. Review the EKS support calendar and plan later upgrades; managed node updates and add-on upgrades are not automatically scheduled by this configuration.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
terraform output -raw get_credentials_command
```

Run the printed `aws eks update-kubeconfig` command using credentials for a configured administrator. If using an assumable administrator role, add `--role-arn YOUR_ADMIN_ROLE_ARN`. Then:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

## Cluster components

Terraform installs managed VPC CNI, kube-proxy, and CoreDNS add-ons using EKS-selected compatible defaults. Control plane logs are retained for 30 days in CloudWatch. The managed node group has configurable size bounds; a Kubernetes autoscaler is not installed and Terraform manages the desired node count.

The node role has worker, ECR image pull, and VPC CNI policies. For this demo the CNI uses the node role; AWS recommends a separate role for CNI permissions. Configure Pod Identity or IAM roles for service accounts when isolating workload permissions. See the [AWS node role guidance](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html).

Install ArgoCD and application components separately. An AWS Load Balancer Controller and its IAM permissions are needed for controller-managed application load balancers; an EBS CSI driver with IAM permissions is needed for dynamic EBS volumes. Neither is included in this network/cluster baseline. Existing `argocd/prod/` manifests are GKE skeletons and need EKS destinations configured.

Direct Agones game-server connectivity requires additional public-node/game-port networking. These private nodes and subnet discovery tags alone do not expose game servers to internet clients.

## State and cleanup

Credentials come from the AWS credential chain; no keys are written in the Terraform files. Local state is used by default. Keep state secure and backed up; the parent `.gitignore` excludes actual variable values, state, plans, and provider downloads. Commit `.terraform.lock.hcl`. Use the repository's SOPS and age workflow for any new secrets.

For team use, configure an S3 backend with a separately provisioned bucket and state locking, then migrate using `terraform init -migrate-state`. Keep each cloud root's state separate.

Before teardown, delete Kubernetes Ingresses, LoadBalancer Services, and provisioned volumes that should be removed, while their controllers still run. Otherwise their AWS resources can remain and prevent VPC deletion. Then run:

```bash
terraform destroy
```

This deletes the resources managed here, including the NAT gateways and log group; it retains the AWS account.

## References

- [Terraform EKS cluster resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [EKS networking requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)
