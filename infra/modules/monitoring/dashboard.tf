resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = concat(
      # Lambda metrics row
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Invocations"
            metrics = [for name in values(var.lambda_functions) : ["AWS/Lambda", "Invocations", "FunctionName", name]]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Errors"
            metrics = [for name in values(var.lambda_functions) : ["AWS/Lambda", "Errors", "FunctionName", name]]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Duration (p99)"
            metrics = [for name in values(var.lambda_functions) : ["AWS/Lambda", "Duration", "FunctionName", name, { stat = "p99" }]]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
      ],
      # API Gateway metrics row
      [
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title = "API Gateway Requests & Errors"
            metrics = [
              ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name],
              ["AWS/ApiGateway", "5XXError", "ApiName", var.api_gateway_name],
              ["AWS/ApiGateway", "4XXError", "ApiName", var.api_gateway_name],
            ]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
      ],
      # DynamoDB metrics row
      [
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title = "DynamoDB Consumed Capacity"
            metrics = [
              ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name],
              ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.dynamodb_table_name],
            ]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title = "DynamoDB Throttled Requests"
            metrics = [
              ["AWS/DynamoDB", "ThrottledRequests", "TableName", var.dynamodb_table_name],
            ]
            view    = "timeSeries"
            stacked = false
            region  = "ap-southeast-2"
            period  = 300
          }
        },
      ]
    )
  })
}