locals {
  # El nombre es global en Azure. Sale del id del grupo de carga: es estable
  # mientras exista el grupo, también si se pierde el estado de terraform.
  registry_name = "${var.azure_acr_name}${substr(sha256(data.azurerm_resource_group.main.id), 0, 16)}"
}

resource "azurerm_container_registry" "main" {
  name                = local.registry_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.azure_resource_tags
}
