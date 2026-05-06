
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

# Attach inline policy for logging
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    sid = "AllowLogWriting"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
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

# --- Deployment Package ---
# Archive the source directory, upload to S3, and reference from Lambda.
data "archive_file" "lambda_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/handlers"
  output_path = "${path.module}/files/lambda-handlers.zip"
}

# Upload the deployment package to S3
resource "aws_s3_object" "lambda_package" {
  bucket = var.s3_bucket
  key    = "packages/${var.name_prefix}/lambda-handlers-${data.archive_file.lambda_source.output_md5}.zip"
  source = data.archive_file.lambda_source.output_path
  etag   = data.archive_file.lambda_source.output_md5

  tags = {
    Name    = "lambda-handlers"
    Version = data.archive_file.lambda_source.output_md5
  }
}

# --- CloudWatch Log Groups ---
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${var.name_prefix}-${replace(each.key, "_", "-")}"
  retention_in_days = 14

  tags = {
    Name     = "/aws/lambda/${var.name_prefix}-${replace(each.key, "_", "-")}"
    Function = each.key
  }
}

# --- Lambda Functions ---
# resource "aws_lambda_function" "lambda" {
#   for_each = var.lambda_functions

#   function_name = "${var.name_prefix}-${replace(each.key, "_", "-")}"
#   description = each.value.description
#   role = aws_iam_role.lambda_exec_role.arn
#   handler = each.value.handler
#   runtime = var.runtime

#   # function_name = "${var.name_prefix}-${replace(each.key, "_", "-")}"
#   # handler       = each.value.handler
#   # runtime       = "python3.9"
#   # role          = aws_iam_role.lambda_exec_role.arn
#   # description   = each.value.description

#   # environment {
#   #   variables = {
#   #     DYNAMODB_TABLE = var.dynamodb_arn
#   #   }
#   # }

#   depends_on = [ 
#     aws_cloudwatch_log_group.lambda_log_group,
#   ]

#   tags = {
#     Name     = "${var.name_prefix}-${replace(each.key, "_", "-")}"
#     Function = each.key
#   }
# }
