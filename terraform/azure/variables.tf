variable "subscription_id" {
  description = "Existing Azure subscription ID."
  type        = string
}

variable "location" {
  description = "Azure region for the cluster and network."
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Cluster name and prefix for Azure resource names."
  type        = string
  default     = "multiplayer-demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "Use 2-40 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "vnet_cidr" {
  description = "Virtual network IPv4 address space."
  type        = string
  default     = "10.40.0.0/16"
}

variable "node_cidr" {
  description = "Node subnet IPv4 range, contained within vnet_cidr."
  type        = string
  default     = "10.40.0.0/20"
}

variable "pod_cidr" {
  description = "Overlay Pod range; must not overlap the VNet or Service range."
  type        = string
  default     = "10.50.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes Service range; must not overlap VNet or Pods. Address 10 is reserved for DNS."
  type        = string
  default     = "10.60.0.0/20"

  validation {
    condition     = can(cidrnetmask(var.service_cidr)) && can(cidrhost(var.service_cidr, 10))
    error_message = "Provide an IPv4 CIDR large enough to contain DNS address 10."
  }
}

variable "admin_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API (workstation or VPN IP with /32)."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")])
    error_message = "Provide at least one valid IPv4 CIDR; /0 is not allowed for administrator access."
  }
}

variable "admin_group_object_ids" {
  description = "Existing Microsoft Entra group object IDs whose members administer Kubernetes, in the subscription tenant."
  type        = list(string)

  validation {
    condition     = length(var.admin_group_object_ids) > 0 && alltrue([for id in var.admin_group_object_ids : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))])
    error_message = "Provide at least one Microsoft Entra group object ID in UUID format."
  }
}

variable "node_count" {
  description = "Number of nodes in the system pool, which also runs demo workloads."
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && floor(var.node_count) == var.node_count
    error_message = "node_count must be a positive integer."
  }
}

variable "vm_size" {
  description = "Azure VM size for each node; must be supported for AKS system pools in the selected region."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "disk_size_gb" {
  description = "Managed OS disk size per node in GB."
  type        = number
  default     = 64

  validation {
    condition     = var.disk_size_gb >= 30 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "disk_size_gb must be an integer of at least 30."
  }
}

variable "availability_zones" {
  description = "Optional node availability zones supported by the selected region and VM size, for example zones 1, 2, and 3."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for zone in var.availability_zones : contains(["1", "2", "3"], zone)])
    error_message = "Availability zones must be 1, 2, or 3."
  }
}

variable "sku_tier" {
  description = "AKS control plane tier. Free is the demo default; Standard provides an uptime SLA."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    project     = "multiplayer-demo"
    environment = "demo"
    managed_by  = "terraform"
  }
}
