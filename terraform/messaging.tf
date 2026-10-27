# ==============================================================================
# AMAZON SQS — Desacoplamiento asíncrono de pedidos (RF-2, D09)
# ==============================================================================

# Dead Letter Queue: recibe los mensajes que fallan repetidamente
resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${local.name}-orders-dlq"
  message_retention_seconds = 1209600 # 14 días para análisis
  sqs_managed_sse_enabled   = true

  tags = { Name = "${local.name}-orders-dlq" }
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name}-orders-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  receive_wait_time_seconds  = var.sqs_wait_time_seconds
  message_retention_seconds  = 345600 # 4 días
  sqs_managed_sse_enabled    = true   # Cifrado en reposo — RNF-6

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = { Name = "${local.name}-orders-queue" }
}

# Solo la cola de pedidos puede usar esta DLQ
resource "aws_sqs_queue_redrive_allow_policy" "orders_dlq" {
  queue_url = aws_sqs_queue.orders_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.orders.arn]
  })
}
