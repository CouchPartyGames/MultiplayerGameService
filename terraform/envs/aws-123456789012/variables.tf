variable "admin_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API."
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "Existing IAM role or user ARNs granted cluster administrator access."
  type        = set(string)
}
