output "azure_kubernetes_cluster_fqdn" {
  description = "Return the fully qualified domain name (FQDN) of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "azure_kubernetes_cluster_name" {
  description = "Return the name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}
