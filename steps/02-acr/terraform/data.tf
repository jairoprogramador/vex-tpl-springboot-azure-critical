# Lo crea el bootstrap: la identidad de despliegue no puede crear grupos de recursos.
data "azurerm_resource_group" "main" {
  name = var.azure_resource_group_name
}
