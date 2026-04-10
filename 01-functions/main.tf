terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

resource "random_id" "suffix" {
  byte_length = 4
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

resource "azurerm_resource_group" "notes" {
  name     = "notes-rg"
  location = var.location
}
