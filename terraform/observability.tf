locals {
  alerts_topic_arn = "arn:aws:sns:${var.aws_region}:${local.account_id}:${var.alerts_topic_name}"
}

locals {
  api_dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = aws_api_gateway_stage.this.stage_name
  }
  lambda_dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-api-5xx"
  alarm_description   = "Erros 5XX na API (falha na Lambda ou na integracao)"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = local.api_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alerts_topic_arn]
  ok_actions          = [local.alerts_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "api_latency_p99" {
  alarm_name          = "${local.name}-api-latency-p99"
  alarm_description   = "Latencia p99 da API acima do limite"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  dimensions          = local.api_dimensions
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_latency_p99_ms
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alerts_topic_arn]
  ok_actions          = [local.alerts_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name}-lambda-errors"
  alarm_description   = "Excecoes nao tratadas na Lambda"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = local.lambda_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alerts_topic_arn]
  ok_actions          = [local.alerts_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name}-lambda-throttles"
  alarm_description   = "Lambda sem concorrencia disponivel (pico acima do limite da conta)"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = local.lambda_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alerts_topic_arn]
  ok_actions          = [local.alerts_topic_arn]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2,
        properties = {
          markdown = "## Startup XYZ (${var.environment}): API Gateway, Lambda e S3\nAlarmes publicam em **${var.alerts_topic_name}**. Bucket: `${aws_s3_bucket.documents.bucket}`"
        }
      },
      {
        type = "metric", x = 0, y = 2, width = 8, height = 6,
        properties = {
          title  = "API: requisicoes e erros"
          region = var.aws_region
          stat   = "Sum", period = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", local.api_dimensions.ApiName, "Stage", local.api_dimensions.Stage],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 2, width = 8, height = 6,
        properties = {
          title  = "API: latencia (ms)"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", local.api_dimensions.ApiName, "Stage", local.api_dimensions.Stage, { stat = "p50" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 2, width = 8, height = 6,
        properties = {
          title  = "Lambda: invocacoes, erros e throttles"
          region = var.aws_region
          stat   = "Sum", period = 60
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", local.lambda_dimensions.FunctionName],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 8, width = 8, height = 6,
        properties = {
          title  = "Lambda: duracao (ms)"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", local.lambda_dimensions.FunctionName, { stat = "Average" }],
            ["...", { stat = "Maximum" }],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 8, width = 8, height = 6,
        properties = {
          title  = "Lambda: concorrencia"
          region = var.aws_region
          stat   = "Maximum", period = 60
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", local.lambda_dimensions.FunctionName],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 8, width = 8, height = 6,
        properties = {
          title  = "S3: objetos e bytes (diario)"
          region = var.aws_region
          stat   = "Average", period = 86400
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.documents.bucket, "StorageType", "AllStorageTypes"],
            [".", "BucketSizeBytes", ".", ".", ".", "StandardStorage", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "alarm", x = 0, y = 14, width = 24, height = 3,
        properties = {
          title = "Alarmes"
          alarms = [
            aws_cloudwatch_metric_alarm.api_5xx.arn,
            aws_cloudwatch_metric_alarm.api_latency_p99.arn,
            aws_cloudwatch_metric_alarm.lambda_errors.arn,
            aws_cloudwatch_metric_alarm.lambda_throttles.arn,
          ]
        }
      },
    ]
  })
}
