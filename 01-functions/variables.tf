variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

variable "b2c_tenant_id" {
  description = "Azure AD B2C tenant ID (GUID)"
  type        = string
}

variable "b2c_tenant_name" {
  description = "B2C tenant name prefix (e.g. 'contosob2c' from contosob2c.onmicrosoft.com)"
  type        = string
}

variable "b2c_policy_name" {
  description = "B2C user flow policy name (e.g. 'B2C_1_signupsignin')"
  type        = string
}

variable "b2c_sp_client_id" {
  description = "Client ID of a service principal registered IN the B2C tenant"
  type        = string
}

variable "b2c_sp_client_secret" {
  description = "Client secret of the B2C tenant service principal"
  type        = string
  sensitive   = true
}
