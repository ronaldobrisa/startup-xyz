# Autenticacao: Cognito User Pool (tier Lite, 10 mil MAU gratuitos) + App Client sem secret.
# O API Gateway valida o ID token; a Lambda usa o claim cognito:username como id do tenant.

resource "aws_cognito_user_pool" "this" {
  name                = "${local.name}-users"
  user_pool_tier      = "LITE"
  deletion_protection = var.cognito_deletion_protection

  # Usuarios sao provisionados pelo operador (sem auto-cadastro publico).
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  username_configuration {
    case_sensitive = false
  }
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "${local.name}-api-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
