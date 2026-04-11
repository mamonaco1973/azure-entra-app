# Entra External ID app registration for the notes SPA.
# The redirect URI points at the web storage account created in storage.tf,
# so that resource is provisioned before this one (Terraform resolves the dep).
resource "azuread_application" "notes" {
  display_name = "notes-entra-app"

  # SPA platform: authorization code + PKCE, no client secret, no implicit flow.
  single_page_application {
    redirect_uris = [
      "${azurerm_storage_account.web.primary_web_endpoint}callback.html"
    ]
  }
}
