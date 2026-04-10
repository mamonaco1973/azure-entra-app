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
  features {}
}

resource "random_id" "suffix" {
  byte_length = 4
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

resource "azurerm_resource_group" "webapp" {
  name     = "notes-webapp-rg"
  location = var.location
}
