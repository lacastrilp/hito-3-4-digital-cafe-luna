provider "aws" {
  region = var.aws_region

  # RNF-4 / D13: etiquetas FinOps obligatorias en todos los recursos
  default_tags {
    tags = local.common_tags
  }
}
