
# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.name_prefix}-api"
  description = "API Gateway for ${var.name_prefix} serverless application"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.name_prefix}-api"
  }
}

## API Gateway Resource
# /items path
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "items"
}

# /items/{id} path
resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# Lambda permissions for API Gateway to invoke functions
resource "aws_lambda_permission" "api_gateway" {
  for_each = var.lambda_functions

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# --- Deployment & Stage ---
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items.id,
      aws_api_gateway_resource.item.id,
      module.items_route.redeployment_hash,
      module.item_route.redeployment_hash,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    module.items_route,
    module.item_route,
  ]
}

# custom log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = 14

  tags = {
    Name = "${var.name_prefix}-api-logs"
  }
}

# stage 
resource "aws_api_gateway_stage" "main" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = "dev-stage"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name = "${var.name_prefix}-api-stage"
  }
}
