# ==============================================================================
# IAM — Rol de mínimo privilegio para las EC2 del ASG (RNF-2, D11)
# Sin Access Keys: las EC2 obtienen credenciales temporales STS vía IMDSv2.
# ==============================================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_app" {
  name               = "${local.name}-role-ec2-app"
  description        = "Rol de las EC2 del ASG de Digital Cafe Luna"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = { Name = "${local.name}-role-ec2-app" }
}

data "aws_iam_policy_document" "ec2_app" {
  # S3: solo lectura de los prefijos que usa la app (no puede borrar ni listar otros buckets)
  statement {
    sid     = "ReadCatalogAndState"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.assets.arn}/catalog/*",
      "${aws_s3_bucket.assets.arn}/state/*",
    ]
  }

  # SQS: productor (/checkout) y consumidor (worker) sobre la cola de pedidos
  statement {
    sid    = "UseOrdersQueue"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.orders.arn]
  }

  # CloudWatch Logs: la EC2 solo PRODUCE logs en su Log Group
  statement {
    sid    = "WriteOpsLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.ops.arn}:*"]
  }

  # Secrets Manager: leer únicamente el secreto de la BD generado por RDS
  statement {
    sid       = "ReadDbSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "ec2_app" {
  name   = "${local.name}-policy-ec2-app"
  role   = aws_iam_role.ec2_app.id
  policy = data.aws_iam_policy_document.ec2_app.json
}

# Acceso administrativo por AWS Systems Manager Session Manager en lugar de SSH:
# no se abre el puerto 22 y cada sesión queda auditada en CloudTrail.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${local.name}-profile-ec2-app"
  role = aws_iam_role.ec2_app.name
}
