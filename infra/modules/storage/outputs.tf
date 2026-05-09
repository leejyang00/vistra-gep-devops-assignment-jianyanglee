output "bucket_id" {
  description = "S3 bucket name for Lambda deployment packages"
  value       = aws_s3_bucket.lambda_deployments.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.lambda_deployments.arn
}

output "bucket_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.lambda_deployments.bucket_regional_domain_name
}
