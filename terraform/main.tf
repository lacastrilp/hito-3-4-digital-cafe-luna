# ==============================================================================
# DIGITAL CAFÉ LUNA — INFRAESTRUCTURA COMO CÓDIGO (Grupo 1 · EAFIT 2026-2)
# Implementa el diagrama de arquitectura del Hito 2 (IaaS 3 capas Multi-AZ).
#
# El código está dividido por capas (Terraform carga todos los *.tf del directorio):
#   main.tf          -> datos compartidos y locals
#   network.tf       -> VPC, IGW, 6 subredes, NAT Gateways, tablas de rutas, NACL
#   security.tf      -> Security Groups encadenados ALB -> EC2 -> RDS
#   storage.tf       -> Amazon S3 (activos/catálogo/estado) cifrado y privado
#   database.tf      -> Amazon RDS PostgreSQL Multi-AZ
#   messaging.tf     -> Amazon SQS (cola de pedidos + DLQ)
#   iam.tf           -> IAM Role / Instance Profile de mínimo privilegio
#   compute.tf       -> ALB, Target Group, Listeners, Launch Template, ASG
#   dns.tf           -> Route 53 (zona, alias al ALB, health check)
#   observability.tf -> CloudWatch Logs, Metric Filter, Alarmas, SNS, Dashboard
#   finops.tf        -> AWS Budgets
# ==============================================================================

data "aws_caller_identity" "current" {}

# AMI más reciente de Amazon Linux 2023 (evita IDs de AMI fijos por región)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name       = var.project_prefix
  account_id = data.aws_caller_identity.current.account_id
  az_suffix  = ["a", "b"]

  common_tags = {
    "dcl:project"     = var.project_tag
    "dcl:environment" = var.environment
    "dcl:owner-team"  = var.owner_team
    "dcl:managed-by"  = "terraform"
  }

  # Nombre global único del bucket (incluye Account ID)
  assets_bucket_name = "${var.project_prefix}-assets-${local.account_id}-${var.owner_team}"
  state_key          = "state/dcl-state.json"
  catalog_key        = "catalog/products.json"

  log_group_name = "/dcl/${var.environment}/ops"

  nat_count    = var.single_nat_gateway ? 1 : length(var.availability_zones)
  enable_https = var.acm_certificate_arn != ""
}
