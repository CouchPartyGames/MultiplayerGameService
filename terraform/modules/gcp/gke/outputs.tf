output "network_name" {
  description = "Created VPC network."
  value       = google_compute_network.gke.name
}

output "subnet_name" {
  description = "Created subnet with Pod and Service secondary ranges."
  value       = google_compute_subnetwork.gke.name
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.gke.name
}

output "cluster_location" {
  description = "GKE cluster zone."
  value       = google_container_cluster.gke.location
}

output "node_service_account" {
  description = "Service account used by GKE nodes."
  value       = google_service_account.nodes.email
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl after apply."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.gke.name} --zone ${google_container_cluster.gke.location} --project ${var.project_id}"
}
