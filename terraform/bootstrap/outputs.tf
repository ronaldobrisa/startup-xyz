output "terraform_state_bucket" {
  description = "Bucket de estado remoto (usar em -backend-config e na variavel AWS_STATE_BUCKET do GitHub)"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "ci_role_arn" {
  description = "ARN da role OIDC (usar na variavel TERRAFORM_ROLE_ARN do GitHub)"
  value       = aws_iam_role.ci.arn
}

output "budget_name" {
  value = aws_budgets_budget.monthly_cost.name
}

output "alerts_topic_arn" {
  description = "Topico SNS dos alarmes (a assinatura de e-mail precisa ser confirmada uma vez)"
  value       = aws_sns_topic.alerts.arn
}
