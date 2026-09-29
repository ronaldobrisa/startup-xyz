# Exemplo: producao. Bucket nao pode ser destruido com dados; User Pool protegido.
environment                 = "prod"
force_destroy_bucket        = false
cognito_deletion_protection = "ACTIVE"
log_retention_days          = 90
presigned_url_ttl_seconds   = 300
archive_after_days          = 365
lambda_memory_mb            = 512
api_throttle_rate           = 100
api_throttle_burst          = 200
