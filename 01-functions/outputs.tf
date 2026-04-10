output "function_app_name" {
  value = azurerm_function_app_flex_consumption.notes.name
}

output "function_app_url" {
  value = "https://${azurerm_function_app_flex_consumption.notes.default_hostname}/api"
}

output "resource_group_name" {
  value = azurerm_resource_group.notes.name
}
