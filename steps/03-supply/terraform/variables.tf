/*VARIABLES OBLIGATORIAS*/
variable "app_environment" {
  description = "Define the environment of the deployment (sand, stag, prod)"
  type        = string
}

variable "app_project_name" {
  description = "Define the name of the project"
  type        = string
  validation {
    condition     = length(var.app_project_name) > 0
    error_message = "The project name cannot be empty"
  }
}

variable "app_team_name" {
  description = "Define the name of the team responsible for the project"
  type        = string
  validation {
    condition     = length(var.app_team_name) > 0
    error_message = "The team name cannot be empty"
  }
}

variable "azure_resource_group_name" {
  description = "Name of the workload resource group created by the bootstrap (VEX_AZURE_RESOURCE_GROUP)"
  type        = string
}

variable "azure_node_resource_group_name" {
  description = "Name that AKS gives to its node resource group, decided by the bootstrap (VEX_BOOTSTRAP_NODE_RESOURCE_GROUP)"
  type        = string
}

variable "aks_identity_id" {
  description = "Resource id of the control plane identity created by the bootstrap (VEX_BOOTSTRAP_AKS_IDENTITY_ID)"
  type        = string
}

variable "kubelet_identity_id" {
  description = "Resource id of the kubelet identity created by the bootstrap (VEX_AZURE_PULL_IDENTITY_ID)"
  type        = string
}

variable "kubelet_client_id" {
  description = "Client id of the kubelet identity (VEX_AZURE_PULL_CLIENT_ID)"
  type        = string
}

variable "kubelet_object_id" {
  description = "Object (principal) id of the kubelet identity (VEX_BOOTSTRAP_PULL_PRINCIPAL_ID)"
  type        = string
}

/*VARIABLES OPCIONALES*/
variable "azure_resource_tags" {
  description = "Define the common tags applied to all Azure resources"
  type        = map(string)
  default = {
    owner       = "fastdeploy@fastdeploy.com"
    cost_center = "fastdeploy"
    compliance  = "RGPD is example"
    create_by   = "fastdeploy"
    lifecycle   = "ephemeral"
  }
}

variable "azure_kubernetes_cluster_name" {
  description = "Define the name of the Azure Kubernetes Service (AKS) cluster"
  type        = string
  default     = "vexkcn"
}

variable "azure_kubernetes_cluster_node_count" {
  description = "Define the initial number of nodes in the default pool of the AKS cluster"
  type        = number
  default     = 1
  validation {
    condition     = var.azure_kubernetes_cluster_node_count >= 1 && var.azure_kubernetes_cluster_node_count <= 100
    error_message = "The number of nodes must be between 1 and 100."
  }
}

variable "azure_kubernetes_cluster_vm_size" {
  description = "Define the size of the virtual machines for the nodes of the AKS cluster"
  type        = string
  default     = "standard_a2_v2"
}

variable "azure_dns_prefix_aks" {
  description = "Define the DNS prefix for the Azure Kubernetes Service cluster"
  type        = string
  default     = "vexdns"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.azure_dns_prefix_aks))
    error_message = "The DNS prefix must contain only lowercase letters, numbers and hyphens."
  }

}
