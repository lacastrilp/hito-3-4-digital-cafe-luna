# ==============================================================================
# VARIABLES — Valores por defecto alineados 1:1 con el diagrama del Hito 2
# ==============================================================================

# --- Identificación y gobierno (RNF-4) ---------------------------------------

variable "aws_region" {
  description = "Región de AWS (diagrama Hito 2: us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefijo de nomenclatura de todos los recursos"
  type        = string
  default     = "dcl-dev"
}

variable "project_tag" {
  description = "Valor del tag obligatorio dcl:project"
  type        = string
  default     = "digital-cafe-luna"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
}

variable "owner_team" {
  description = "Equipo responsable (Grupo 1)"
  type        = string
  default     = "team-01"
}

# --- Red: direccionamiento exacto del diagrama del Hito 2 --------------------

variable "vpc_cidr" {
  description = "CIDR de la VPC (Hito 2: 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZ A y AZ B"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "El diagrama del Hito 2 exige exactamente 2 Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Capa pública: Subnet Pública 1 (AZ A) y 2 (AZ B) — ALB + NAT Gateway"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "compute_subnet_cidrs" {
  description = "Capa de cómputo privada: Subnet Privada Cómputo 1 (AZ A) y 2 (AZ B) — EC2 ASG"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "data_subnet_cidrs" {
  description = "Capa de datos aislada: Subnet Datos 1 (AZ A, RDS Primary) y 2 (AZ B, RDS Standby)"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "single_nat_gateway" {
  description = "false = 1 NAT Gateway por AZ (fiel al diagrama). true = 1 solo NAT (ahorro FinOps en dev)"
  type        = bool
  default     = false
}

# --- DNS / Route 53 y TLS -----------------------------------------------------

variable "enable_route53" {
  description = "Crea la zona Route 53, el registro alias hacia el ALB y el health check"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Dominio de la zona hospedada en Route 53"
  type        = string
  default     = "digitalcafeluna-grupo1.com"
}

variable "acm_certificate_arn" {
  description = "ARN de un certificado ACM validado. Si se define, el ALB expone HTTPS/443 y redirige 80 -> 443"
  type        = string
  default     = ""
}

# --- Cómputo EC2 + Auto Scaling Group ----------------------------------------

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Puerto de la aplicación en EC2 (Hito 2: SG-EC2-App 8080 solo desde SG-ALB)"
  type        = number
  default     = 8080
}

variable "asg_min_size" {
  description = "Mínimo de instancias del ASG"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Capacidad deseada (EC2 Instance A + EC2 Instance B)"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Máximo de instancias del ASG"
  type        = number
  default     = 4
}

variable "cpu_target_utilization" {
  description = "Objetivo de CPU (%) para la política de escalado target tracking"
  type        = number
  default     = 60
}

# --- RDS PostgreSQL Multi-AZ --------------------------------------------------

variable "db_engine_version" {
  description = "Versión mayor de PostgreSQL"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "Clase de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nombre de la base de datos transaccional"
  type        = string
  default     = "digitalcafeluna"
}

variable "db_username" {
  description = "Usuario maestro (la contraseña la genera y custodia AWS Secrets Manager)"
  type        = string
  default     = "dcl_admin"
}

variable "db_backup_retention_days" {
  description = "Días de backups automáticos / PITR"
  type        = number
  default     = 7
}

# --- Mensajería SQS -----------------------------------------------------------

variable "sqs_visibility_timeout" {
  description = "VisibilityTimeout (s) de la cola de pedidos"
  type        = number
  default     = 30
}

variable "sqs_wait_time_seconds" {
  description = "Long polling (s) de la cola de pedidos"
  type        = number
  default     = 5
}

variable "sqs_max_receive_count" {
  description = "Reintentos antes de enviar un mensaje a la DLQ"
  type        = number
  default     = 5
}

# --- Observabilidad y FinOps --------------------------------------------------

variable "log_retention_days" {
  description = "Retención del Log Group /dcl/<env>/ops"
  type        = number
  default     = 7
}

variable "metric_namespace" {
  description = "Namespace de la métrica personalizada ErrorCount"
  type        = string
  default     = "DigitalCafeLuna/LAB3"
}

variable "cpu_alarm_threshold" {
  description = "Umbral de la alarma de CPU del ASG (Hito 2: CPU > 75 %)"
  type        = number
  default     = 75
}

variable "alert_email" {
  description = "Correo para notificaciones SNS y AWS Budgets (vacío = sin suscripción)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual en AWS Budgets (Hito 2: 20 USD)"
  type        = number
  default     = 20
}
