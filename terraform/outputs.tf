output "api_base_url" {
  description = "URL base da API (stage = environment)"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "documents_bucket" {
  value = aws_s3_bucket.documents.bucket
}

output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}
