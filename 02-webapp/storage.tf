resource "azurerm_storage_account" "webapp" {
  name                     = "notesweb${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.webapp.name
  location                 = azurerm_resource_group.webapp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account_static_website" "webapp" {
  storage_account_id = azurerm_storage_account.webapp.id
  index_document     = "index.html"
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.webapp.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "index.html"
  content_type           = "text/html"
  cache_control          = "no-store"

  depends_on = [azurerm_storage_account_static_website.webapp]
}

output "website_url" {
  value = azurerm_storage_account.webapp.primary_web_endpoint
}
