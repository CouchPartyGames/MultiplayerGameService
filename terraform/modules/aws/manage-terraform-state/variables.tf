variable "region" {
  description = "AWS region with at least two available standard availability zones."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name and prefix for network and IAM resources."
  type        = string
  default     = "multiplayer-demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "Use 2-40 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version (for example 1.35); null uses the EKS default at creation. Confirm support in the chosen region."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "IPv4 /16 VPC range; four /20 subnets are derived from it. Avoid overlap with connected networks and Kubernetes Services."
  type        = string
  default     = "10.70.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && endswith(var.vpc_cidr, "/16")
    error_message = "Provide a valid IPv4 /16 CIDR."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for the demo; false creates one per availability zone."
  type        = bool
  default     = true
}

variable "admin_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API."
  type        = list(string)
  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")])
    error_message = "Provide at least one valid IPv4 CIDR; /0 is not allowed for administrator access."
  }
}

variable "admin_principal_arns" {
  description = "Existing IAM role or user ARNs granted cluster administrator access. Use IAM role ARNs, not STS assumed-role session ARNs."
  type        = set(string)
  validation {
    condition     = length(var.admin_principal_arns) > 0 && alltrue([for arn in var.admin_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", arn))])
    error_message = "Provide at least one IAM role or user ARN."
  }
}

variable "instance_type" {
  description = "x86_64 EC2 instance type available in both selected zones."
  type        = string
  default     = "m6i.xlarge"
}

variable "node_scaling" {
  description = "Managed node group size bounds. No autoscaler is installed by this configuration."
  type = object({
    desired = number
    min     = number
    max     = number
  })
  default = { desired = 3, min = 1, max = 5 }
  validation {
    condition = (
      var.node_scaling.min >= 1 &&
      var.node_scaling.min <= var.node_scaling.desired &&
      var.node_scaling.desired <= var.node_scaling.max &&
      alltrue([for n in values(var.node_scaling) : floor(n) == n])
    )
    error_message = "Use integer sizes satisfying 1 <= min <= desired <= max."
  }
}

variable "disk_size_gb" {
  description = "Root disk size per node in GB."
  type        = number
  default     = 50
  validation {
    condition     = var.disk_size_gb >= 20 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "disk_size_gb must be an integer of at least 20."
  }
}

variable "tags" {
  description = "Default tags for AWS resources."
  type        = map(string)
  default = {
    project     = "multiplayer-demo"
    environment = "demo"
    managed_by  = "terraform"
  }
}
