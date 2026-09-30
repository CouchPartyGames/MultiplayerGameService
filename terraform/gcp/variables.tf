variable "project_id" {
  description = "Existing GCP project ID with billing enabled."
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet. The cluster zone must belong to this region."
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zone for the GKE control plane and nodes."
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  description = "Cluster name and prefix for network and service account names."
  type        = string
  default     = "multiplayer-demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.cluster_name))
    error_message = "Use 2-24 lowercase letters, digits, or hyphens; start with a letter and end with a letter or digit."
  }
}

variable "node_cidr" {
  description = "IPv4 subnet range for nodes; must not overlap the Pod or Service ranges."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pod_cidr" {
  description = "Secondary IPv4 range for Pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "service_cidr" {
  description = "Secondary IPv4 range for Kubernetes Services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "admin_cidrs" {
  description = "IPv4 CIDRs allowed to reach the Kubernetes API, such as your public IP with /32."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")])
    error_message = "Provide at least one valid IPv4 CIDR; /0 is not allowed for administrator access."
  }
}

variable "node_count" {
  description = "Number of nodes in the single-zone node pool."
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && floor(var.node_count) == var.node_count
    error_message = "node_count must be a positive integer."
  }
}

variable "machine_type" {
  description = "Compute Engine machine type for each node."
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Balanced persistent boot disk size per node, in GB."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= 20 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "disk_size_gb must be an integer of at least 20."
  }
}

variable "deletion_protection" {
  description = "Require an explicit apply with this set to false before cluster destruction."
  type        = bool
  default     = true
}

variable "enable_agones_udp" {
  description = "Allow inbound game traffic on Agones' default UDP ports 7000-8000."
  type        = bool
  default     = false
}

variable "game_client_cidrs" {
  description = "Source ranges for the optional Agones UDP rule; defaults to public game clients."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.game_client_cidrs) > 0 && alltrue([for cidr in var.game_client_cidrs : can(cidrnetmask(cidr))])
    error_message = "Provide at least one valid IPv4 CIDR for game clients."
  }
}
