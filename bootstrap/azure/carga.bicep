// Grupo de recursos de carga: aquí crea el pipeline el registro de contenedores
// y el clúster del ambiente. Este módulo solo da los permisos sobre él.
param deployPrincipalId string
param kubeletPrincipalId string

var contributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var aksRbacClusterAdmin = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var acrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// Crea el registro (paso acr) y el clúster (paso supply), y construye las
// imágenes en el registro (paso package).
resource deployManagesWorkload 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployPrincipalId, contributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributor)
    principalId: deployPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// «Azure Kubernetes Service RBAC Cluster Admin»: Contributor crea el clúster,
// pero no da acceso a la API de Kubernetes. El paso deploy crea el namespace y
// su cuota, que son objetos del clúster entero. Va sobre el grupo y no sobre el
// clúster porque el clúster aún no existe: lo crea el paso supply.
resource deployAdministersClusters 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployPrincipalId, aksRbacClusterAdmin)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksRbacClusterAdmin)
    principalId: deployPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Sobre el grupo y no sobre el registro, porque el registro aún no existe: lo
// crea el paso acr. Así el pipeline no necesita poder asignar roles.
resource kubeletReadsImages 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, kubeletPrincipalId, acrPull)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPull)
    principalId: kubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}
