output "resource_group_name" {
  description = "Resource group containing the cluster and virtual network."
  value       = module.aks.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "get_credentials_command" {
  description = "Run this command after apply, then run kubelogin convert-kubeconfig -l azurecli."
  value       = module.aks.get_credentials_command
}
