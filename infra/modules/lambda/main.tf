
# IAM role for lambda function
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.name_prefix}-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-lambda-exec-role"
  }
}

# Attach inline policy for logging.
# Log groups are pre-created by Terraform (see aws_cloudwatch_log_group.lambda_log_group),
# so the role only needs CreateLogStream + PutLogEvents scoped to those groups.
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    sid    = "AllowLogWriting"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*:*",
    ]
  }
}

# Attach inline policy for DynamoDB access
data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    sid    = "AllowDynamoDBOperations"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]
    resources = [
      var.dynamodb_arn,
      "${var.dynamodb_arn}/index/*",
    ]
  }
}

# Attach inline policy for S3 access
data "aws_iam_policy_document" "s3_read_lambda" {
  statement {
    sid    = "AllowS3GetDeploymentPackage"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "${var.s3_bucket_arn}/packages/${var.name_prefix}/*",
    ]
  }
}

# combine policies into one document for the role
data "aws_iam_policy_document" "lambda_combined_policy" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_logging.json,
    data.aws_iam_policy_document.dynamodb_access.json,
    data.aws_iam_policy_document.s3_read_lambda.json,
  ]
}

# Attach the combined policy to the role
resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_combined_policy.json
}

# --- CloudWatch Log Groups ---
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${var.name_prefix}-${replace(each.key, "_", "-")}"
  retention_in_days = var.log_retention_days

  tags = {
    Name     = "/aws/lambda/${var.name_prefix}-${replace(each.key, "_", "-")}"
    Function = each.key
  }
}

# --- Lambda Functions ---
resource "aws_lambda_function" "lambda_api_items" {
  for_each = var.lambda_functions

  function_name = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  description   = each.value.description
  role          = aws_iam_role.lambda_exec_role.arn

  handler     = each.value.handler
  runtime     = var.lambda_runtime
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  s3_bucket        = var.s3_bucket
  s3_key           = aws_s3_object.lambda_package[each.key].key
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256

  environment {
    variables = {
      TABLE_NAME  = var.dynamodb_table_name
      ENVIRONMENT = var.environment
      LOG_LEVEL   = upper(var.lambda_log_level)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy.lambda_inline,
  ]

  tags = {
    Name     = "${var.name_prefix}-${replace(each.key, "_", "-")}"
    Function = each.key
  }
}
