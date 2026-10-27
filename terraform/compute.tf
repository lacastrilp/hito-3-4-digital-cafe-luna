# ==============================================================================
# BALANCEO (ALB) Y CÓMPUTO ELÁSTICO (Launch Template + ASG) — D03, D05, D06
# ==============================================================================

# --- Application Load Balancer en las 2 subredes públicas (ALB Node A / B) ---
resource "aws_lb" "main" {
  name                       = "${local.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true

  tags = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-tg-app"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${local.name}-tg-app" }
}

# Listener 80: reenvía al Target Group, o redirige a 443 si hay certificado ACM
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}

# Listener 443 con TLS 1.3 (solo si se entrega un certificado ACM) — RNF-6
resource "aws_lb_listener" "https" {
  count             = local.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- Launch Template: cómo "nace" cada EC2 del ASG ---------------------------
resource "aws_launch_template" "app" {
  name_prefix            = "${local.name}-lt-app-"
  description            = "EC2 de aplicacion Digital Cafe Luna (Docker + CloudWatch Agent)"
  image_id               = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2.id]
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_app.arn
  }

  # IMDSv2 obligatorio: mitiga el robo de credenciales por SSRF
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    region         = var.aws_region
    bucket         = aws_s3_bucket.assets.id
    state_key      = local.state_key
    catalog_key    = local.catalog_key
    queue_url      = aws_sqs_queue.orders.url
    wait_seconds   = var.sqs_wait_time_seconds
    db_host        = aws_db_instance.postgres.address
    db_port        = aws_db_instance.postgres.port
    log_group_name = local.log_group_name
    app_port       = var.app_port
  }))

  # default_tags no se propaga a tag_specifications: se agregan explícitamente
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name}-app-root" })
  }

  tags = { Name = "${local.name}-lt-app" }
}

# --- Auto Scaling Group en las 2 subredes privadas de cómputo ----------------
resource "aws_autoscaling_group" "app" {
  name                = "${local.name}-asg-app"
  min_size            = var.asg_min_size
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  vpc_zone_identifier = aws_subnet.compute[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  # ELB: una instancia que falla el health check del ALB es reemplazada
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Un cambio en el Launch Template reemplaza instancias de forma gradual
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${local.name}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # La NAT y la BD deben existir antes de que arranquen las EC2 (user_data las usa)
  depends_on = [
    aws_route_table_association.compute,
    aws_db_instance.postgres,
  ]
}

# Escalado dinámico por CPU (D06)
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${local.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_utilization
  }
}
