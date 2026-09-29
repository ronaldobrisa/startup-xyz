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

output "lambda_alias_arn" {
  value = aws_lambda_alias.live.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.this.dashboard_name}"
}

output "alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.api_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.api_latency_p99.alarm_name,
    aws_cloudwatch_metric_alarm.lambda_errors.alarm_name,
    aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name,
  ]
}
