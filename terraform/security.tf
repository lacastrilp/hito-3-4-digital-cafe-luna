# ==============================================================================
# SECURITY GROUPS ENCADENADOS (Hito 2, sección 8.1)
#   SG-ALB     : 80/443 desde 0.0.0.0/0
#   SG-EC2-App : app_port (8080) SOLO desde SG-ALB · sin SSH 22
#   SG-RDS-DB  : 5432 SOLO desde SG-EC2-App · sin salida a Internet
# Se usan reglas como recursos independientes para poder referenciar SGs entre
# sí sin dependencias circulares.
# ==============================================================================

resource "aws_security_group" "alb" {
  name        = "${local.name}-sg-alb"
  description = "SG-ALB: HTTP/HTTPS publico hacia el Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-sg-alb" }
}

resource "aws_security_group" "ec2" {
  name        = "${local.name}-sg-ec2-app"
  description = "SG-EC2-App: puerto de aplicacion solo desde SG-ALB, sin SSH"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-sg-ec2-app" }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-sg-rds-db"
  description = "SG-RDS-DB: PostgreSQL 5432 solo desde SG-EC2-App"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-sg-rds-db" }
}

# --- SG-ALB -------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde Internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB -> EC2 en el puerto de aplicacion"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.ec2.id
}

# --- SG-EC2-App ---------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Trafico de aplicacion unicamente desde SG-ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ec2_https" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS saliente via NAT: S3, SQS, CloudWatch, Secrets Manager, SSM, paquetes"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "EC2 -> RDS PostgreSQL"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

# --- SG-RDS-DB (sin reglas de salida: cero acceso a Internet) -----------------
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL unicamente desde SG-EC2-App"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ec2.id
}
