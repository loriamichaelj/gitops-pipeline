output "tenant_id" {
  value = data.azurerm_client_config.this.tenant_id
}

output "subscription_id" {
  value = var.subscription_id
}

output "client_id" {
  value = azurerm_user_assigned_identity.hub.client_id
}

output "audience" {
  value = var.audience
}
