output "sns_topic_arn" {
    description = "ARN of the SNS topic for monitoring alerts"
    value       = aws_sns_topic.monitoring_alerts.arn
}

output "alarm_names" {
    description = "List of CloudWatch alarm names created for monitoring"
    value = concat(
        [for a in aws_cloudwatch_metric_alarm.lambda_errors : a.alarm_name],
        [for a in aws_cloudwatch_metric_alarm.lambda_duration : a.alarm_name],
        [for a in aws_cloudwatch_metric_alarm.lambda_throttles : a.alarm_name],
        [aws_cloudwatch_metric_alarm.api_5xx.alarm_name],
        [aws_cloudwatch_metric_alarm.api_latency.alarm_name],
        [aws_cloudwatch_metric_alarm.dynamodb_throttles.alarm_name],
    )
}
