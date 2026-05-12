# CloudWatch Alarms     →  "something is wrong, tell someone"
# SNS Topic             →  "delivery mechanism for those alerts"
# CloudWatch Dashboard  →  "visual overview for humans watching"


# --- SNS Topic for Alarm Notifications ---
resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

