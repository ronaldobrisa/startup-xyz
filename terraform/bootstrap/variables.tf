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

variable "notification_email" {
  description = "Destinatario dos alertas do AWS Budget e do topico SNS de alarmes"
  type        = string
  default     = "ti.rbrodrigues@gmail.com"
}

variable "monthly_budget_usd" {
  description = "Teto mensal (USD) do Budget com alerta"
  type        = number
  default     = 5
}
