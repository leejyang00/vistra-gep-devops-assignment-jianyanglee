output "execution_role_arn" {
  description = "IAM execution role ARN shared by all CRUD Lambda functions"
  value       = aws_iam_role.lambda_exec_role.arn
}
