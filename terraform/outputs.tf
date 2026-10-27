# --- Red ----------------------------------------------------------------------
output "vpc_id" {
  description = "ID de la VPC (10.0.0.0/16)"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Subredes públicas (ALB + NAT) en AZ A y AZ B"
  value       = aws_subnet.public[*].id
}

output "compute_subnet_ids" {
  description = "Subredes privadas de cómputo (EC2 ASG) en AZ A y AZ B"
  value       = aws_subnet.compute[*].id
}

output "data_subnet_ids" {
  description = "Subredes de datos aisladas (RDS) en AZ A y AZ B"
  value       = aws_subnet.data[*].id
}

output "nat_gateway_public_ips" {
  description = "IPs públicas de salida de los NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# --- Entrada / DNS ------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "URL directa de la aplicación a través del ALB"
  value       = "${local.enable_https ? "https" : "http"}://${aws_lb.main.dns_name}"
}

output "route53_name_servers" {
  description = "Name servers a configurar en el registrador del dominio (delegación)"
  value       = var.enable_route53 ? aws_route53_zone.main[0].name_servers : []
}

output "route53_app_fqdn" {
  description = "Nombre DNS público de la aplicación en Route 53"
  value       = var.enable_route53 ? var.domain_name : "Route 53 desactivado"
}

# --- Cómputo ------------------------------------------------------------------
output "asg_name" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "ARN del Target Group del ALB"
  value       = aws_lb_target_group.app.arn
}

output "launch_template_id" {
  description = "ID del Launch Template"
  value       = aws_launch_template.app.id
}

# --- Datos --------------------------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint privado de RDS PostgreSQL Multi-AZ"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_master_secret_arn" {
  description = "ARN del secreto en Secrets Manager con la contraseña maestra de RDS"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "s3_assets_bucket" {
  description = "Bucket S3 de activos, catálogo y estado"
  value       = aws_s3_bucket.assets.id
}

# --- Mensajería ---------------------------------------------------------------
output "sqs_orders_queue_url" {
  description = "URL de la cola de pedidos"
  value       = aws_sqs_queue.orders.url
}

output "sqs_orders_dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.orders_dlq.url
}

# --- Seguridad y observabilidad -----------------------------------------------
output "ec2_role_arn" {
  description = "ARN del IAM Role de las EC2"
  value       = aws_iam_role.ec2_app.arn
}

output "cloudwatch_log_group" {
  description = "Log Group de la aplicación"
  value       = aws_cloudwatch_log_group.ops.name
}

output "cloudwatch_alarms" {
  description = "Alarmas operacionales creadas"
  value = [
    aws_cloudwatch_metric_alarm.app_errors.alarm_name,
    aws_cloudwatch_metric_alarm.asg_cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.dlq_messages.alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name,
  ]
}

output "dashboard_url" {
  description = "URL del dashboard operacional en la consola"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.ops.dashboard_name}"
}
