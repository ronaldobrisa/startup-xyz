variable "project" {
  description = "Nome curto do projeto; prefixo de todos os recursos"
  type        = string
  default     = "startup-xyz"
}

variable "environment" {
  description = "Ambiente (demo, dev, staging, prod). Entra no nome de todo recurso e na tag Environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.environment))
    error_message = "environment deve ser minusculo, alfanumerico, 2 a 16 caracteres."
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# --- Armazenamento e ciclo de vida -----------------------------------------

variable "archive_after_days" {
  description = "Dias em S3 Standard antes da transicao para Glacier Deep Archive (RF: 365)"
  type        = number
  default     = 365
}

variable "noncurrent_version_expiration_days" {
  description = "Dias ate expirar versoes antigas (protecao contra exclusao acidental sem acumular custo para sempre)"
  type        = number
  default     = 730
}

variable "force_destroy_bucket" {
  description = "Permite destruir o bucket com objetos (true so em ambientes efemeros)"
  type        = bool
  default     = false
}

# --- API e uploads ----------------------------------------------------------

variable "presigned_url_ttl_seconds" {
  description = "Validade das presigned URLs/POSTs gerados pela Lambda"
  type        = number
  default     = 300
}

variable "max_upload_mb" {
  description = "Tamanho maximo por documento, imposto na politica do presigned POST"
  type        = number
  default     = 25
}

variable "api_throttle_rate" {
  description = "Requisicoes/segundo (steady state) no stage do API Gateway"
  type        = number
  default     = 20
}

variable "api_throttle_burst" {
  type    = number
  default = 40
}

# --- Lambda -----------------------------------------------------------------

variable "lambda_memory_mb" {
  type    = number
  default = 256
}

variable "lambda_timeout_seconds" {
  type    = number
  default = 10
}

variable "provisioned_concurrency" {
  description = "Instancias pre-aquecidas no alias 'live' (0 = desligado; cobra por tempo provisionado)"
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "Retencao dos logs da Lambda no CloudWatch"
  type        = number
  default     = 1
}

# --- Identidade -------------------------------------------------------------

variable "cognito_deletion_protection" {
  description = "Protecao contra exclusao do User Pool (ACTIVE em prod; INACTIVE em ambientes efemeros)"
  type        = string
  default     = "ACTIVE"

  validation {
    condition     = contains(["ACTIVE", "INACTIVE"], var.cognito_deletion_protection)
    error_message = "Use ACTIVE ou INACTIVE."
  }
}

# --- Observabilidade --------------------------------------------------------

variable "alerts_topic_name" {
  description = "Nome do topico SNS (criado no bootstrap) que recebe os alarmes"
  type        = string
  default     = "startup-xyz-alerts"
}

variable "alarm_latency_p99_ms" {
  description = "Limite de latencia p99 da API para alarme"
  type        = number
  default     = 3000
}
