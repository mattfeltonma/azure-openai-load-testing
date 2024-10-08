variable "key_vault_administrator" {
    description = "The object id of the user or group that will be assigned the Key Vault Administrator role"
    type        = string
}

variable "key_vault_default_action" {
  description = "The default action for the network ACLs"
  type        = string
  default     = "Allow"
}

variable "location" {
  description = "The region to deploy resources to"
  type        = string
}

variable "purpose" {
  description = "The purpose of the resources"
  type        = string
  default = "loadtest"
}

variable "key_vault_private_dns_zone_id" {
  description = "The id of an existing private DNS zone for Azure Key Vault"
  type        = string
}

variable "secrets" {
  description = "The service principal information used by the load testing service to communicate with the Azure OpenAI Service"
    type        = map(string)
}

variable "subnet_id_pe" {
  description = "The id of the subnet that will be delegated to the Azure Key Vault"
  type        = string
}

variable "tags" {
  description = "The tags to apply to the resources"
  type        = map(string)
}