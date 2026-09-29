terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # bucket, key e region vem por -backend-config (mise run init / CI).
  # use_lockfile = lock nativo do S3 (Terraform >= 1.10), sem tabela DynamoDB.
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Todos os recursos: "<project>-<environment>-..." (casa com o prefixo permitido na role de CI)
  name = "${var.project}-${var.environment}"

  # Prefixo de isolamento por cliente dentro do bucket (slide "Multi-Tenancy Seguro por Design")
  tenant_prefix_pattern = "usuario-*/"
}
