# API Gateway REST: ponto de entrada unico com autenticacao Cognito, validacao de payload
# (JSON Schema, antes de invocar a Lambda), throttling e integracao proxy.
#
#   POST /documents           -> presigned POST de upload em usuario-{id}/<filename>
#   GET  /documents/{key+}    -> presigned URL de download, 403 se a key nao pertencer ao usuario
#
# REST (e nao HTTP API) por causa do validador de requisicao e dos usage plans/WAF futuros. Ver ADR 0005.

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

# --- Validacao de payload ("REST API com validacao", slide 8) --------------

resource "aws_api_gateway_model" "upload_request" {
  rest_api_id  = aws_api_gateway_rest_api.this.id
  name         = "UploadRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema"            = "http://json-schema.org/draft-04/schema#"
    title                = "UploadRequest"
    type                 = "object"
    required             = ["filename", "content_type"]
    additionalProperties = false
    properties = {
      filename = {
        type      = "string"
        minLength = 1
        maxLength = 128
        pattern   = "^[A-Za-z0-9][A-Za-z0-9._-]*$"
      }
      content_type = {
        type = "string"
        enum = ["application/pdf", "image/png", "image/jpeg"]
      }
    }
  })
}

resource "aws_api_gateway_request_validator" "body" {
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  name                        = "validar-body"
  validate_request_body       = true
  validate_request_parameters = false
}

# --- Recursos e metodos -----------------------------------------------------

resource "aws_api_gateway_resource" "documents" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_resource" "document_key" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.documents.id
  path_part   = "{key+}"
}

resource "aws_api_gateway_method" "post_document" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.documents.id
  http_method          = "POST"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.cognito.id
  request_validator_id = aws_api_gateway_request_validator.body.id

  request_models = {
    "application/json" = aws_api_gateway_model.upload_request.name
  }
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
  uri                     = aws_lambda_alias.live.invoke_arn
}

resource "aws_api_gateway_integration" "get_document" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.document_key.id
  http_method             = aws_api_gateway_method.get_document.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_alias.live.invoke_arn
}

# --- Deployment e stage -----------------------------------------------------

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Qualquer mudanca de configuracao (nao so recriacao) gera novo deployment.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.documents,
      aws_api_gateway_resource.document_key,
      aws_api_gateway_method.post_document,
      aws_api_gateway_method.get_document,
      aws_api_gateway_integration.post_document,
      aws_api_gateway_integration.get_document,
      aws_api_gateway_authorizer.cognito,
      aws_api_gateway_model.upload_request,
      aws_api_gateway_request_validator.body,
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
    metrics_enabled        = true
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }
}
