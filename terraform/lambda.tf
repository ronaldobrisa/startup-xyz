# Funcao unica (Python 3.12, sem dependencias) empacotada pelo proprio Terraform.

data "archive_file" "api" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

# Declarado explicitamente para (a) controlar retencao e (b) ser destruido junto com o resto.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.name}-api"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "api" {
  function_name = "${local.name}-api"
  description   = "Gera presigned URLs de upload/download isoladas por prefixo usuario-{id}/"

  role    = aws_iam_role.lambda.arn
  runtime = "python3.12"
  handler = "handler.lambda_handler"

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  architectures = ["arm64"]
  memory_size   = var.lambda_memory_mb
  timeout       = var.lambda_timeout_seconds

  environment {
    variables = {
      BUCKET_NAME     = aws_s3_bucket.documents.bucket
      URL_TTL_SECONDS = tostring(var.presigned_url_ttl_seconds)
      ENVIRONMENT     = var.environment
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.api.name
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy.lambda,
  ]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
