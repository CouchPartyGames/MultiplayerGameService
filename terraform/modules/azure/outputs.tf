output "resource_group_name" {
  description = "Resource group containing the cluster and virtual network."
  value       = azurerm_resource_group.aks.name
}

output "virtual_network_id" {
  description = "Created virtual network ID."
  value       = azurerm_virtual_network.aks.id
}

output "node_subnet_id" {
  description = "Subnet used by AKS nodes."
  value       = azurerm_subnet.nodes.id
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "node_resource_group" {
  description = "Resource group managed by AKS for nodes and load balancers."
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer for configuring workload identity federated credentials."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "get_credentials_command" {
  description = "Run this command after apply, then run kubelogin convert-kubeconfig -l azurecli."
  value       = "az aks get-credentials --subscription ${var.subscription_id} --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
