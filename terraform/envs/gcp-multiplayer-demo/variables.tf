variable "admin_cidrs" {
  description = "IPv4 CIDRs allowed to reach the Kubernetes API, such as your public IP with /32."
  type        = list(string)
}
