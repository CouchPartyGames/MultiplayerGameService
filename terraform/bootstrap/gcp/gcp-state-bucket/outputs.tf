output "bucket_name" {
  description = "Name of the state bucket, for the `bucket` argument of a `gcs` backend block."
  value       = google_storage_bucket.state.name
}

output "bucket_url" {
  description = "gs:// URL of the state bucket."
  value       = google_storage_bucket.state.url
}

output "backend_config" {
  description = "Backend block to paste into a root module; replace the prefix with one unique to that module."
  value       = <<-EOT
    terraform {
      backend "gcs" {
        bucket = "${google_storage_bucket.state.name}"
        prefix = "<root-module-name>"
      }
    }
  EOT
}
