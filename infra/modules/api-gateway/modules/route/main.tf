resource "aws_api_gateway_method" "this" {
  for_each = var.integrations

  rest_api_id        = var.rest_api_id
  resource_id        = var.resource_id
  http_method        = each.value.http_method
  authorization      = "NONE"
  request_parameters = var.request_parameters
}

resource "aws_api_gateway_integration" "this" {
  for_each = var.integrations

  rest_api_id             = var.rest_api_id
  resource_id             = var.resource_id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.invoke_arn
}
