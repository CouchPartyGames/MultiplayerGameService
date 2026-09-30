# Azure network and AKS

This Terraform root creates a resource group, virtual network, node subnet, user-assigned cluster identity with Network Contributor access to the subnet, and an AKS cluster in an existing subscription.

The defaults are East US, three `Standard_D4s_v5` Ubuntu nodes, 64 GB managed OS disks, and the Free control plane tier. The system pool also runs demo workloads. Set `sku_tier = "Standard"` and supported `availability_zones` when an uptime SLA and node distribution across zones are needed.

Azure CNI Overlay uses separate Pod and Service ranges. Nodes have private IPs; a Standard Load Balancer supplies managed outbound connectivity. The public Kubernetes API is restricted to `admin_cidrs`. Microsoft Entra group members authenticate using `kubelogin`, and Kubernetes RBAC gives the configured groups administrator access. Local cluster accounts are disabled. OIDC and workload identity are enabled; individual workloads still require federated credentials and Azure role assignments.

## Prerequisites

- Terraform 1.5 through 1.x, Azure CLI, `kubectl`, and `kubelogin` on your PATH.
- An existing Azure subscription with sufficient VM quota, including capacity for one surge node during upgrades.
- An identity with Contributor access to create resources and permission to create role assignments, for example Role Based Access Control Administrator at the subscription scope. Azure resource provider registration also requires subscription permissions; the AzureRM provider handles its default registrations.
- An existing Microsoft Entra group in the subscription's tenant containing the intended cluster administrators. Supply its **object ID**, not its display name.

## Deploy

From this directory:

```bash
az login
az account set --subscription YOUR_SUBSCRIPTION_ID
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your subscription ID, administrator group object IDs, and workstation or VPN public IP CIDR. The example IDs and IP are placeholders. The node subnet must fit inside the VNet. VNet, Pod, and Service ranges must not overlap each other or connected networks. Confirm the VM size and any selected availability zones are available in your region.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
terraform output -raw get_credentials_command
```

Run the printed `az aks get-credentials` command, then authenticate as a member of one of the administrator groups:

```bash
kubelogin convert-kubeconfig -l azurecli
kubectl get nodes
```

Group members also need Azure permission to download user credentials, such as the Azure Kubernetes Service Cluster User Role on the cluster. Group membership controls Kubernetes administrator access; it does not grant that Azure permission automatically. The provisioning identity's Contributor role includes credential retrieval.

The AKS recommended Kubernetes version is selected at creation, with the `stable` automatic upgrade channel and `NodeImage` OS updates thereafter. New identity role assignments can take time to propagate; if Azure reports a subnet authorization error immediately after the role is created, allow propagation and retry the apply.

## Applications and state

Install ArgoCD, Agones, and other Kubernetes components separately. Existing `argocd/prod/` manifests target the GKE skeleton and need Azure cluster destinations configured. This baseline has no public node IPs or game-port ingress rules: direct Agones game-server connectivity requires an additional public-node/game-port design. Kubernetes Services of type LoadBalancer can provision application ingress through AKS.

Private Azure Container Registry pulls require an appropriate registry role for the AKS kubelet identity. Cluster workload identity is configured independently of image-pull permissions.

Terraform authenticates through Azure CLI locally. State is local by default and may contain sensitive data; keep it secure and backed up. The parent `.gitignore` excludes state, actual variable values, plans, and downloaded providers. Commit `.terraform.lock.hcl`. For team use, configure an `azurerm` backend with a separately provisioned storage account and container, then migrate state with `terraform init -migrate-state`. Use SOPS and age for any new repository secrets.

## Destroy

Remove Kubernetes workloads, LoadBalancer Services, and provisioned volumes that should be cleaned up before deleting the cluster. Then run:

```bash
terraform destroy
```

This deletes the cluster, its managed node resource group, and the network/resource group created here. The subscription is retained. Avoid putting unrelated resources in either resource group.

## References

- [AzureRM AKS resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [Azure CNI Overlay networking](https://learn.microsoft.com/azure/aks/azure-cni-overlay)
- [Managed Microsoft Entra integration](https://learn.microsoft.com/azure/aks/enable-authentication-microsoft-entra-id)
