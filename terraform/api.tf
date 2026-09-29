# API Gateway REST: ponto de entrada unico, autenticacao Cognito, throttling, integracao proxy com a Lambda.
#
#   POST /documents           -> presigned URL de upload em usuario-{id}/<filename>
#   GET  /documents/{key+}    -> presigned URL de download, 403 se a key nao pertencer ao usuario

resource "aws_api_gateway_rest_api" "this" {
  name        = "${local.name}-api"
  description = "Ingestao e recuperacao segura de documentos (Startup XYZ)"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.this.arn]
  identity_source = "method.request.header.Authorization"
}

# /documents
resource "aws_api_gateway_resource" "documents" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "documents"
}

# /documents/{key+}
resource "aws_api_gateway_resource" "document_key" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.documents.id
  path_part   = "{key+}"
}

resource "aws_api_gateway_method" "post_document" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.documents.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "get_document" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.document_key.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.key" = true
  }
}

resource "aws_api_gateway_integration" "post_document" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.documents.id
  http_method             = aws_api_gateway_method.post_document.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "get_document" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.document_key.id
  http_method             = aws_api_gateway_method.get_document.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Qualquer mudanca na API gera novo deployment.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.documents.id,
      aws_api_gateway_resource.document_key.id,
      aws_api_gateway_method.post_document.id,
      aws_api_gateway_method.get_document.id,
      aws_api_gateway_integration.post_document.id,
      aws_api_gateway_integration.get_document.id,
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_document,
    aws_api_gateway_integration.get_document,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }
}
