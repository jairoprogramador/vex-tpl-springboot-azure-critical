// Grupo de recursos de identidades: las tres identidades del ambiente y el
// candado que las protege. Ninguna recibe aquí una credencial federada.
param location string
param baseName string
param tags object

var managedIdentityOperator = 'f1a07417-d97a-45cb-824c-7a7467783830'
var managedIdentityOperatorId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperator)

// Con la que el pipeline entra a Azure (vex le añade después la credencial federada).
resource deploy 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${baseName}-deploy'
  location: location
  tags: tags
}

// La del plano de control del clúster.
resource aks 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${baseName}-aks'
  location: location
  tags: tags
}

// La de los nodos: con ella descargan las imágenes del registro. Se crea aquí,
// antes que el clúster, para que su permiso sobre el registro se dé en el
// bootstrap y el pipeline no necesite poder asignar roles.
resource kubelet 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${baseName}-kubelet'
  location: location
  tags: tags
}

// La identidad de despliegue puede asignar las otras dos al clúster, pero no
// cambiarles credenciales ni permisos.
resource deployAssignsAks 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, deploy.id, managedIdentityOperator)
  scope: aks
  properties: {
    roleDefinitionId: managedIdentityOperatorId
    principalId: deploy.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployAssignsKubelet 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kubelet.id, deploy.id, managedIdentityOperator)
  scope: kubelet
  properties: {
    roleDefinitionId: managedIdentityOperatorId
    principalId: deploy.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// AKS lo exige cuando la identidad del kubelet la aporta el usuario: el plano
// de control la asigna a los nodos.
resource aksAssignsKubelet 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kubelet.id, aks.id, managedIdentityOperator)
  scope: kubelet
  properties: {
    roleDefinitionId: managedIdentityOperatorId
    principalId: aks.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource protectIdentities 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'vex-protect-identities'
  properties: {
    level: 'CanNotDelete'
    notes: 'Identidades del pipeline de vex: no borrar a mano.'
  }
}

output deployIdentityId string = deploy.id
output deployClientId string = deploy.properties.clientId
output deployPrincipalId string = deploy.properties.principalId
output aksIdentityId string = aks.id
output kubeletIdentityId string = kubelet.id
output kubeletClientId string = kubelet.properties.clientId
output kubeletPrincipalId string = kubelet.properties.principalId
