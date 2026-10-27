# ==============================================================================
# OBSERVABILIDAD — CloudWatch Logs, Metric Filter, Alarmas, SNS, Dashboard
# (RNF-3, D12, Hito 4)
# ==============================================================================

resource "aws_cloudwatch_log_group" "ops" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = { Name = "${local.name}-log-group-ops" }
}

# Cada línea de log con "ERROR" se convierte en ErrorCount = 1
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${local.name}-error-filter"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.ops.name

  metric_transformation {
    name          = "ErrorCount"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# --- Notificaciones -----------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"

  tags = { Name = "${local.name}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Alarmas ------------------------------------------------------------------

# 1. Errores de aplicación (HTTP 500)
resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${local.name}-ops-alarm"
  alarm_description   = "Errores de aplicacion (lineas ERROR en ${local.log_group_name})"
  namespace           = var.metric_namespace
  metric_name         = "ErrorCount"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# 2. CPU del ASG > 75 % (Hito 2, D12)
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "${local.name}-asg-cpu-high"
  alarm_description   = "CPU promedio del ASG supera ${var.cpu_alarm_threshold}%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# 3. Mensajes en la DLQ de SQS (Hito 2, D12)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name}-orders-dlq-not-empty"
  alarm_description   = "Hay pedidos que fallaron ${var.sqs_max_receive_count} veces y quedaron en la DLQ"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.orders_dlq.name
  }
}

# 4. Targets no saludables detrás del ALB
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name}-alb-unhealthy-hosts"
  alarm_description   = "Al menos un target del ALB esta unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

# --- Dashboard operacional ----------------------------------------------------
resource "aws_cloudwatch_dashboard" "ops" {
  dashboard_name = "${local.name}-ops-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "alarm", x = 0, y = 0, width = 24, height = 3
        properties = {
          title = "Estado de operacion"
          alarms = [
            aws_cloudwatch_metric_alarm.app_errors.arn,
            aws_cloudwatch_metric_alarm.asg_cpu_high.arn,
            aws_cloudwatch_metric_alarm.dlq_messages.arn,
            aws_cloudwatch_metric_alarm.unhealthy_hosts.arn,
          ]
        }
      },
      {
        type = "metric", x = 0, y = 3, width = 8, height = 6
        properties = {
          title   = "ErrorCount (HTTP 500)", region = var.aws_region, view = "timeSeries"
          stat    = "Sum", period = 60
          metrics = [[var.metric_namespace, "ErrorCount"]]
        }
      },
      {
        type = "metric", x = 8, y = 3, width = 8, height = 6
        properties = {
          title   = "CPU promedio ASG", region = var.aws_region, view = "timeSeries"
          stat    = "Average", period = 300
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name]]
        }
      },
      {
        type = "metric", x = 16, y = 3, width = 8, height = 6
        properties = {
          title  = "ALB: peticiones y latencia", region = var.aws_region, view = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 9, width = 12, height = 6
        properties = {
          title = "SQS: backlog de pedidos y DLQ", region = var.aws_region, view = "timeSeries"
          stat  = "Maximum", period = 60
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.orders.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.orders_dlq.name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 9, width = 12, height = 6
        properties = {
          title  = "RDS: CPU y conexiones", region = var.aws_region, view = "timeSeries"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.postgres.identifier, { stat = "Average" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.postgres.identifier, { stat = "Average", yAxis = "right" }],
          ]
        }
      },
    ]
  })
}
