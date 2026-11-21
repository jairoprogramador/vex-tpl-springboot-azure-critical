/*VARIABLES OBLIGATORIAS*/
variable "azure_resource_group_name" {
  description = "Name of the workload resource group created by the bootstrap (VEX_AZURE_RESOURCE_GROUP)"
  type        = string
}

/*VARIABLES OPCIONALES*/
variable "azure_acr_name" {
  description = "Define the prefix of the name of the Azure Container Registry"
  type        = string
  default     = "vexacr"
  validation {
    condition     = can(regex("^[a-z0-9]{1,30}$", var.azure_acr_name))
    error_message = "The prefix must contain only lowercase letters and numbers (up to 30)."
  }
}

variable "azure_resource_tags" {
  description = "Define the common tags applied to all Azure resources"
  type        = map(string)
  default = {
    cost_center = "vex"
    create_by   = "vex"
    lifecycle   = "ephemeral"
  }
}
