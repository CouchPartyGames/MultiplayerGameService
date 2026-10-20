terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# IAM is global, but the provider still needs a region. Replace the account ID
# with the account this bootstrap prepares.
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["123456789012"]

  default_tags {
    tags = {
      project    = "multiplayer-demo"
      managed_by = "terraform"
      component  = "bootstrap"
    }
  }
}
