# ==============================================================================
# FINOPS — AWS Budgets (RNF-4, D13: presupuesto mensual de 20 USD)
# Las etiquetas dcl:* se aplican globalmente desde providers.tf (default_tags).
# ==============================================================================

resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Aviso al 80 % del gasto real
  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }

  # Aviso cuando el pronóstico supera el 100 %
  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
