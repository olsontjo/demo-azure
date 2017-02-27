variable "azurerm_client_id" {
  type = "string"
}

variable "azurerm_client_secret" {
  type = "string"
}

variable "azurerm_instances" {
  type    = "string"
  default = "3"
}

variable "azurerm_location" {
  type    = "string"
  default = "East US"
}

variable "azurerm_subscription_id" {
  type = "string"
}

variable "azurerm_tenant_id" {
  type = "string"
}

variable "azurerm_vm_admin_password" {
  type = "string"
}

variable "cloudflare_email" {
  type = "string"
}

variable "cloudflare_token" {
  type = "string"
}
