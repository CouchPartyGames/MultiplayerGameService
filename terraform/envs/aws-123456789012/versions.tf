terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["123456789012"]

  default_tags {
    tags = {
      project     = "multiplayer-demo"
      environment = "demo"
      managed_by  = "terraform"
    }
  }
}
