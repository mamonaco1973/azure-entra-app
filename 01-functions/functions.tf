resource "azurerm_storage_account" "functions" {
  name                     = "notesb2cfunc${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.notes.name
  location                 = azurerm_resource_group.notes.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "func_code" {
  name                  = "func-code"
  storage_account_id    = azurerm_storage_account.functions.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "notes" {
  name                = "notes-b2c-plan"
  resource_group_name = azurerm_resource_group.notes.name
  location            = azurerm_resource_group.notes.location
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_application_insights" "notes" {
  name                = "notes-b2c-ai"
  resource_group_name = azurerm_resource_group.notes.name
  location            = azurerm_resource_group.notes.location
  application_type    = "web"
}

resource "azurerm_function_app_flex_consumption" "notes" {
  name                = "notes-b2c-func-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.notes.name
  location            = azurerm_resource_group.notes.location

  service_plan_id = azurerm_service_plan.notes.id
  https_only      = true

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.functions.primary_blob_endpoint}${azurerm_storage_container.func_code.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.functions.primary_access_key

  runtime_name    = "python"
  runtime_version = "3.11"

  maximum_instance_count = 50
  instance_memory_in_mb  = 2048

  site_config {
    cors {
      # Restrict to the exact web storage origin so the browser accepts
      # requests that carry an Authorization header.
      allowed_origins     = [trimsuffix(azurerm_storage_account.web.primary_web_endpoint, "/")]
      support_credentials = false
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION           = "~4"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.notes.connection_string
    COSMOS_ENDPOINT                       = azurerm_cosmosdb_account.notes.endpoint
    COSMOS_KEY                            = azurerm_cosmosdb_account.notes.primary_key
    COSMOS_DATABASE                       = azurerm_cosmosdb_sql_database.notes.name
    COSMOS_CONTAINER                      = azurerm_cosmosdb_sql_container.notes.name
    AzureWebJobsFeatureFlags              = "EnableWorkerIndexing"
    B2C_TENANT_NAME                       = var.b2c_tenant_name
    B2C_TENANT_ID                         = var.b2c_tenant_id
    B2C_POLICY_NAME                       = var.b2c_policy_name
    B2C_CLIENT_ID                         = azuread_application.notes.client_id
  }

  lifecycle {
    ignore_changes = [
      app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"],
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      app_settings["SCM_DO_BUILD_DURING_DEPLOYMENT"],
    ]
  }
}
