# ==============================================================================
# AMAZON RDS POSTGRESQL MULTI-AZ (RF-4, RNF-6, D07)
#   Primary en Subnet Datos 1 (AZ A) · Standby síncrona en Subnet Datos 2 (AZ B)
# ==============================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnet-group"
  description = "Subredes de datos aisladas (AZ A y AZ B) para RDS Multi-AZ"
  subnet_ids  = aws_subnet.data[*].id

  tags = { Name = "${local.name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true # KMS en reposo (clave administrada aws/rds) — RNF-6

  multi_az = true # Réplica síncrona standby en la otra AZ con failover automático

  db_name  = var.db_name
  username = var.db_username
  # Sin contraseñas en el código ni en el state: RDS la genera y la guarda en
  # AWS Secrets Manager. Las EC2 la leen con su IAM Role (ver iam.tf).
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  backup_retention_period = var.db_backup_retention_days # Backups diarios + PITR
  backup_window           = "07:00-08:00"
  maintenance_window      = "sun:08:30-sun:09:30"

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  apply_immediately          = true

  # Entorno académico: permite destroy limpio. En producción: true / false.
  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${local.name}-db" }
}
