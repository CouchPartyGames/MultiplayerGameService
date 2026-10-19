variable "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. Bucket names are global across AWS, so include something unique such as the account ID."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use 3-63 lowercase letters, digits, dots, or hyphens, starting and ending with a letter or digit."
  }
}

variable "create_lock_table" {
  description = "Create a DynamoDB table for state locking. Terraform 1.10+ can lock with the S3 bucket alone (backend `use_lockfile = true`), and the backend's `dynamodb_table` argument is deprecated from 1.11, so set false once every caller uses S3 locking."
  type        = bool
  default     = true
}

variable "lock_table_name" {
  description = "Name of the DynamoDB state lock table."
  type        = string
  default     = "terraform-state-lock"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.lock_table_name))
    error_message = "Use 3-255 letters, digits, underscores, dots, or hyphens."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting the bucket and lock table; null uses SSE-S3 for the bucket and the AWS managed DynamoDB key for the table."
  type        = string
  default     = null
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "Provide a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>) or null."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep noncurrent (overwritten or deleted) state file versions before S3 expires them."
  type        = number
  default     = 90
  validation {
    condition     = var.noncurrent_version_retention_days >= 1 && floor(var.noncurrent_version_retention_days) == var.noncurrent_version_retention_days
    error_message = "Use a whole number of days, 1 or more."
  }
}

variable "tags" {
  description = "Tags applied to the bucket and lock table."
  type        = map(string)
  default     = {}
}
