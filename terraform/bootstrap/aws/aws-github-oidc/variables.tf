variable "github_org" {
  description = "GitHub organization or user that owns the repository allowed to assume the role."
  type        = string
  default     = "CouchPartyGames"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_org))
    error_message = "Use the GitHub owner name only: letters, digits, or hyphens."
  }
}

variable "github_repo" {
  description = "GitHub repository, without the owner, allowed to assume the role."
  type        = string
  default     = "MultiplayerGameService"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "Use the repository name only: letters, digits, underscores, dots, or hyphens."
  }
}

variable "github_subjects" {
  description = "OIDC subject suffixes allowed to assume the role, appended to `repo:<org>/<repo>:`. Examples: `ref:refs/heads/main`, `pull_request`, `environment:production`. `*` and `?` wildcards are allowed (StringLike)."
  type        = list(string)
  default     = ["ref:refs/heads/main", "pull_request"]
  validation {
    condition     = length(var.github_subjects) > 0 && alltrue([for s in var.github_subjects : length(trimspace(s)) > 0 && s != "*"])
    error_message = "List at least one subject, and do not use a bare `*`, which would let any branch, tag, or environment assume the role."
  }
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions assumes; workflows pass its ARN to aws-actions/configure-aws-credentials."
  type        = string
  default     = "github-actions"
  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "Use 1-64 letters, digits, or + = , . @ _ - characters."
  }
}

variable "max_session_duration" {
  description = "Maximum session length, in seconds, for credentials issued to the role."
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Use 3600 to 43200 seconds (1 to 12 hours)."
  }
}

variable "role_policy_statements" {
  description = "Statements for the role's inline policy: what GitHub Actions may do in the account. Grant only what the workflows need."
  type = list(object({
    sid       = string
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  validation {
    condition     = length(var.role_policy_statements) > 0
    error_message = "List at least one statement."
  }
  validation {
    condition     = alltrue([for s in var.role_policy_statements : contains(["Allow", "Deny"], s.effect)])
    error_message = "Each statement's effect must be Allow or Deny."
  }
  validation {
    condition     = alltrue([for s in var.role_policy_statements : can(regex("^[A-Za-z0-9]*$", s.sid))])
    error_message = "Each sid may contain only letters and digits."
  }
}
