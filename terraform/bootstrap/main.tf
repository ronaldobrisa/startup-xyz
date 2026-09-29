# Bootstrap: recursos permanentes da conta que NAO participam do ciclo apply/destroy da demo.
# Aplicado uma vez, localmente, com estado local (terraform.tfstate neste diretorio).
#
#   - bucket S3 de estado remoto (versionado, criptografado, sem acesso publico, lock nativo)
#   - role IAM assumida pelo GitHub Actions via OIDC, com minimo privilegio
#   - AWS Budget mensal com alerta por e-mail

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "bootstrap"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = var.aws_region

  state_bucket_name = "${var.project}-tfstate-${local.account_id}"
  ci_role_name      = "gh-actions-${var.project}"

  # Prefixo de nomes que a role de CI pode gerenciar. Tudo que a demo cria usa "<project>-<env>-...".
  managed_prefix = "${var.project}-*"
}

# ---------------------------------------------------------------------------
# Bucket de estado remoto
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "terraform_state_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.terraform_state]
}

# ---------------------------------------------------------------------------
# Role OIDC do GitHub Actions
# ---------------------------------------------------------------------------

# O provedor OIDC ja existe na conta (compartilhado entre projetos); apenas referenciado.
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "ci_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Somente este repositorio: branch main (push e workflow_dispatch) e pull requests.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "ci" {
  name                 = local.ci_role_name
  description          = "GitHub Actions (${var.github_repo}): plan em PR, apply/destroy manual"
  assume_role_policy   = data.aws_iam_policy_document.ci_assume_role.json
  max_session_duration = 3600
}

# Minimo privilegio por servico. Cada statement e restrito por ARN ao prefixo do projeto
# sempre que o servico permite; onde nao permite (Describe/List globais), o recurso e "*".
data "aws_iam_policy_document" "ci" {
  statement {
    sid       = "Identity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # --- Estado remoto -------------------------------------------------------
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  # --- S3 do projeto (bucket de documentos) --------------------------------
  statement {
    sid       = "ProjectBuckets"
    actions   = ["s3:*"]
    resources = ["arn:${local.partition}:s3:::${local.managed_prefix}"]
  }

  statement {
    sid       = "ProjectBucketObjects"
    actions   = ["s3:*"]
    resources = ["arn:${local.partition}:s3:::${local.managed_prefix}/*"]
  }

  # --- Lambda ---------------------------------------------------------------
  statement {
    sid       = "ProjectLambda"
    actions   = ["lambda:*"]
    resources = ["arn:${local.partition}:lambda:${local.region}:${local.account_id}:function:${local.managed_prefix}"]
  }

  # --- API Gateway (nao suporta restricao por nome; restrito a REST APIs da regiao) ---
  statement {
    sid     = "ProjectApiGateway"
    actions = ["apigateway:GET", "apigateway:POST", "apigateway:PUT", "apigateway:PATCH", "apigateway:DELETE"]
    resources = [
      "arn:${local.partition}:apigateway:${local.region}::/restapis",
      "arn:${local.partition}:apigateway:${local.region}::/restapis/*",
      "arn:${local.partition}:apigateway:${local.region}::/tags/*",
    ]
  }

  # --- Cognito --------------------------------------------------------------
  statement {
    sid       = "ProjectCognito"
    actions   = ["cognito-idp:*"]
    resources = ["arn:${local.partition}:cognito-idp:${local.region}:${local.account_id}:userpool/*"]
  }

  statement {
    sid       = "CognitoCreateAndList"
    actions   = ["cognito-idp:CreateUserPool", "cognito-idp:ListUserPools"]
    resources = ["*"]
  }

  # --- CloudWatch Logs ------------------------------------------------------
  statement {
    sid       = "ProjectLogGroups"
    actions   = ["logs:*"]
    resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.managed_prefix}"]
  }

  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # --- IAM (somente roles/politicas do projeto) ----------------------------
  statement {
    sid = "ProjectIamRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${local.managed_prefix}"]
  }

  statement {
    sid       = "ProjectIamPassRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${local.managed_prefix}"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  # --- Tagging API (check-orphans) -----------------------------------------
  statement {
    sid       = "TaggingRead"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "${local.ci_role_name}-policy"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci.json
}

# ---------------------------------------------------------------------------
# Budget: rede de seguranca contra recurso orfao
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Project$%s", var.project)] # formato da API: user:<chave>$<valor>
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.notification_email]
  }
}
