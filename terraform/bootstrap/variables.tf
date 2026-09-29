variable "project" {
  description = "Nome curto do projeto; prefixo de todos os recursos"
  type        = string
  default     = "startup-xyz"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  description = "owner/repo autorizado a assumir a role de CI via OIDC"
  type        = string
  default     = "ronaldobrisa/startup-xyz"
}

variable "github_actor" {
  description = "Unico usuario do GitHub cujas execucoes podem assumir a role de CI (claim actor no sub do token OIDC)"
  type        = string
  default     = "ronaldobrisa"
}

variable "notification_email" {
  description = "Destinatario dos alertas do AWS Budget e do topico SNS de alarmes"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Teto mensal (USD) do Budget com alerta"
  type        = number
  default     = 5
}
