output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "get_credentials_command" {
  description = "Command that configures kubectl for the cluster."
  value       = module.eks.get_credentials_command
}
