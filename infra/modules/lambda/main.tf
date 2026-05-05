
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

# combine policies into one document for the role
data "aws_iam_policy_document" "lambda_combined_policy" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_logging.json,
    data.aws_iam_policy_document.dynamodb_access.json,
  ]
}

# Attach the combined policy to the role
resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_combined_policy.json
}
