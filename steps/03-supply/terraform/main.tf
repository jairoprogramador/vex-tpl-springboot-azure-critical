resource "azurerm_kubernetes_cluster" "main" {
  name                = local.kubernetes_cluster
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = local.dns_prefix

  node_resource_group = var.azure_node_resource_group_name

  default_node_pool {
    name       = "default"
    node_count = var.azure_kubernetes_cluster_node_count
    vm_size    = var.azure_kubernetes_cluster_vm_size
  }

  # Las dos identidades las crea el bootstrap, con sus permisos ya asignados:
  # este paso no asigna ningún rol.
  identity {
    type         = "UserAssigned"
    identity_ids = [var.aks_identity_id]
  }

  # Con ella los nodos descargan las imágenes: tiene AcrPull sobre el grupo de carga, donde está el registro.
  kubelet_identity {
    user_assigned_identity_id = var.kubelet_identity_id
    client_id                 = var.kubelet_client_id
    object_id                 = var.kubelet_object_id
  }

  local_account_disabled = true
  azure_policy_enabled   = true

  # Quién entra a la API de Kubernetes lo deciden los roles de Azure; el de la
  # identidad de despliegue lo asigna el bootstrap.
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  tags = local.tags
}
