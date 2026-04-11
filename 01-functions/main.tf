terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Points at the B2C tenant, not the main subscription tenant.
# Requires a service principal registered IN the B2C tenant with
# Application.ReadWrite.All on Microsoft Graph.
provider "azuread" {
  tenant_id     = var.b2c_tenant_id
  client_id     = var.b2c_sp_client_id
  client_secret = var.b2c_sp_client_secret
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "notes" {
  name     = "notes-b2c-rg"
  location = var.location
}
