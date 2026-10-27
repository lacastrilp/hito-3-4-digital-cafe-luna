# ==============================================================================
# AMAZON S3 — Activos, imágenes del catálogo y estado (RF-3, RNF-6, D08)
# ==============================================================================

resource "aws_s3_bucket" "assets" {
  bucket        = local.assets_bucket_name
  force_destroy = true # Permite terraform destroy en entorno académico

  tags = { Name = local.assets_bucket_name }
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced" # Desactiva ACLs
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Cifrado en reposo con AWS KMS (clave administrada aws/s3) — RNF-6
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true # Reduce llamadas (y costo) a KMS
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# FinOps: versiones antiguas expiran a los 30 días
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

# Cifrado en tránsito obligatorio: se rechaza cualquier petición sin TLS — RNF-6
data "aws_iam_policy_document" "assets_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

# --- Objetos semilla ----------------------------------------------------------

resource "aws_s3_object" "state" {
  bucket       = aws_s3_bucket.assets.id
  key          = local.state_key
  content_type = "application/json"
  content = jsonencode({
    project     = "Digital Cafe Luna"
    environment = var.environment
    message     = "Estado persistente almacenado fuera de EC2"
    version     = 1
  })
}

resource "aws_s3_object" "catalog" {
  bucket       = aws_s3_bucket.assets.id
  key          = local.catalog_key
  content_type = "application/json"
  content = jsonencode({
    products = [
      { sku = "CAF-001", name = "Cafe Luna Origen Huila 500g", price_cop = 32000, image = "catalog/img/caf-001.jpg" },
      { sku = "CAF-002", name = "Cafe Luna Descafeinado 250g", price_cop = 21000, image = "catalog/img/caf-002.jpg" },
    ]
  })

  depends_on = [aws_s3_bucket_versioning.assets]
}
