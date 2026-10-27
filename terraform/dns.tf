# ==============================================================================
# AMAZON ROUTE 53 — DNS / Health Check (Hito 2: Clientes -> Route 53 -> ALB)
# Etapa 5 del plan de migración (cutover): el registro alias apunta al ALB.
# ==============================================================================

resource "aws_route53_zone" "main" {
  count   = var.enable_route53 ? 1 : 0
  name    = var.domain_name
  comment = "Zona DNS del canal digital de Digital Cafe Luna"

  # Entorno académico: permite destruir la zona aunque tenga registros
  force_destroy = true
}

# Registro alias A (apex) -> ALB. evaluate_target_health propaga la salud del ALB.
resource "aws_route53_record" "app" {
  count   = var.enable_route53 ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  count   = var.enable_route53 ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Health check externo de Route 53 sobre el endpoint /health a través del ALB
resource "aws_route53_health_check" "app" {
  count             = var.enable_route53 ? 1 : 0
  fqdn              = aws_lb.main.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "${local.name}-r53-health" }
}
