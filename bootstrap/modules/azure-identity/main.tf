data "azurerm_client_config" "this" {}

resource "azurerm_resource_group" "identity" {
  name     = var.resource_group_name
  location = var.location
  tags     = { repo = "gitops-pipeline", managed-by = "opentofu" }
}

# One identity for every provider family: the Azure ClusterProviderConfig carries a
# single client ID.
resource "azurerm_user_assigned_identity" "hub" {
  name                = var.identity_name
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = { repo = "gitops-pipeline", managed-by = "opentofu" }
}

# Only the matching Kubernetes service account, with the expected audience, may
# exchange its token for the identity.
resource "azurerm_federated_identity_credential" "hub" {
  for_each = toset(var.service_accounts)

  name                = each.value
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.hub.id
  issuer              = var.issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${each.value}"
  audience            = [var.audience]
}

resource "azurerm_role_assignment" "hub" {
  for_each = toset(var.roles)

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.hub.principal_id
  principal_type       = "ServicePrincipal"
}
