locals {
  tags = merge({
    "project_name" : var.app_project_name,
    "project_team" : var.app_team_name,
    "environment" : var.app_environment,
  }, var.azure_resource_tags)

  # Hay un grupo de recursos por ambiente: dentro de él los nombres no chocan.
  kubernetes_cluster = "${var.azure_kubernetes_cluster_name}${var.app_environment}"
  dns_prefix         = "${var.azure_dns_prefix_aks}${var.app_environment}"
}
