variable "project_id" {
  description = "GCP project ID that owns the state bucket."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Use a GCP project ID: 6-30 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "bucket_name" {
  description = "Globally unique name of the state bucket. Defaults to `<project_id>-tfstate`."
  type        = string
  default     = null
  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use 3-63 lowercase letters, digits, hyphens, or underscores, starting and ending with a letter or digit."
  }
}

variable "location" {
  description = "Bucket location: a region such as `US-EAST1`, a dual-region, or a multi-region such as `US`."
  type        = string
  default     = "US-EAST1"
  validation {
    condition     = var.location == upper(var.location)
    error_message = "Write the location in upper case, as GCS reports it, so plans stay clean."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep a state version after a newer one replaces it."
  type        = number
  default     = 90
  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "Keep noncurrent versions for at least 1 day."
  }
}

variable "kms_key_name" {
  description = "Cloud KMS key (`projects/.../cryptoKeys/...`) for CMEK encryption. Null uses Google-managed encryption."
  type        = string
  default     = null
  validation {
    condition     = var.kms_key_name == null || can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.kms_key_name))
    error_message = "Use the full key name: projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>."
  }
}

variable "state_users" {
  description = "IAM members granted roles/storage.objectUser on the bucket so they can read, write, and lock state, such as `serviceAccount:atlantis@<project>.iam.gserviceaccount.com`."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for m in var.state_users : can(regex("^(user|serviceAccount|group|principal|principalSet):.+", m))])
    error_message = "Prefix each member with its type, such as `serviceAccount:` or `group:`."
  }
}

variable "labels" {
  description = "Extra labels for the bucket, merged with the provider's default labels."
  type        = map(string)
  default     = {}
}
