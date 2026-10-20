variable "admin_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API."
  type        = list(string)
}

variable "admin_group_object_ids" {
  description = "Existing Microsoft Entra group object IDs whose members administer Kubernetes."
  type        = list(string)
}
