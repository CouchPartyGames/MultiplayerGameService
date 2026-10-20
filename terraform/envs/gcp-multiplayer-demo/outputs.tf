output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "GKE cluster zone."
  value       = module.gke.cluster_location
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl after apply."
  value       = module.gke.get_credentials_command
}
