// Almacenamiento del estado de Terraform. Se despliega en el grupo de recursos
// de identidades: allí la identidad de despliegue no tiene ningún permiso de
// gestión, así que no puede reactivar las llaves de cuenta, quitar el versionado
// ni borrar la cuenta. Solo lee y escribe blobs del contenedor de estado.
param location string
param baseName string
param tags object
param deployPrincipalId string

var storageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

var stateContainerName = 'tfstate'
// El nombre es global en Azure: primero la parte única (13 caracteres) y luego
// lo que quepa del nombre legible, para que dos ambientes nunca coincidan.
var stateAccountName = take('st${uniqueString(resourceGroup().id)}${toLower(replace(baseName, '-', ''))}', 24)

resource stateAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: stateAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // Sin llaves de cuenta: al estado solo se entra con identidad (Entra ID).
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource stateBlobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: stateAccount
  name: 'default'
  properties: {
    // Un estado sobrescrito por error se recupera de la versión anterior.
    isVersioningEnabled: true
  }
}

resource stateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: stateBlobs
  name: stateContainerName
}

// Acotado al contenedor: es un rol de datos, no da gestión sobre la cuenta.
resource deployWritesState 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(stateContainer.id, deployPrincipalId, storageBlobDataContributor)
  scope: stateContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributor)
    principalId: deployPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output stateAccount string = stateAccount.name
output stateContainer string = stateContainerName
