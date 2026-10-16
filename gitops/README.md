# GitOps

The platform is delivered in two layers. The infrastructure layer provides the clusters and cloud resources; the application layer runs on top of those clusters.

## Infrastructure Layer

The infrastructure layer is the cloud resources the platform runs on, such as:

- Managed Kubernetes clusters: AWS EKS, Azure AKS, Google GKE
- Networking: VPCs, subnets, load balancers, DNS
- Identity and access: IAM roles, service accounts, managed identities
- Supporting services: container registries, storage, databases

These resources are defined as infrastructure as code. In this repo they live in `terraform/`, with one configuration per cloud provider.

## Application Layer

The application layer is the Kubernetes objects deployed into those clusters, such as pods, services, deployments, config maps, and custom resources like Agones Fleets.

Workloads are usually packaged in one of three ways:

- **Helm**: charts configured with values files
- **Kustomize**: base manifests with environment overlays
- **Plain manifests**: Kubernetes YAML files applied as-is

ArgoCD syncs these packages from Git to the cluster. In this repo, ArgoCD Applications live in `argocd/` and Helm values files live in `helm/external-values/`.
