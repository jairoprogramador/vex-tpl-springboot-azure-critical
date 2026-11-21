// Bootstrap de la plantilla (contrato azure/v1): AKS y registro de contenedores
// por ambiente. Nada se comparte entre ambientes: la identidad de despliegue de
// uno no tiene ningún permiso sobre lo que usa otro.
//
// Crea lo que el pipeline necesita y no puede crearse a sí mismo: los grupos de
// recursos, las identidades y sus permisos, y el almacenamiento del estado de
// Terraform. Todos los roles se asignan aquí: los pasos del pipeline no asignan
// ninguno. La confianza (credencial federada `vex-oidc` sobre la identidad de
// despliegue) NO va aquí: la crea vex después de aplicar esta plantilla.
targetScope = 'subscription'

// --- Parámetros que pasa vex -------------------------------------------------
@description('Id del proyecto en vex (uuid).')
param projectId string

@description('Nombre corto del proyecto calculado por vex: [a-z0-9-], hasta 20 caracteres.')
param projectSlug string

@description('Ambiente al que pertenece esta conexión (sand, stag, prod…).')
param environment string

@description('Región de los grupos de recursos y de todo lo que se crea en ellos.')
param location string

// --- Parámetros propios (todos con valor por defecto) ------------------------
@description('Presupuesto mensual del ambiente (grupo de carga y grupo de nodos), en la moneda de la suscripción. 0 no crea presupuesto.')
@minValue(0)
param budgetAmount int = 0

@description('Correos que reciben el aviso al llegar al 80 %. Azure exige al menos uno si hay presupuesto.')
param budgetEmails array = []

@description('Primer día del mes en curso: Azure no admite presupuestos mensuales que empiecen en un mes anterior.')
param budgetStartDate string = utcNow('yyyy-MM-01')

var baseName = 'vex-${projectSlug}-${environment}'
var tags = {
  'vex:managed': 'true'
  'vex:project': projectId
  'vex:environment': environment
}
// Lo crea AKS para sus máquinas, discos y balanceador; el pipeline no entra en él.
var nodeGroupName = 'rg-${baseName}-nodes'

// Las identidades y el estado de Terraform viven en su propio grupo: la
// identidad de despliegue no tiene ningún permiso de gestión sobre él, así que
// no puede cambiarse a sí misma ni reconfigurar la cuenta de estado.
resource identityGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${baseName}-id'
  location: location
  tags: tags
}

resource workloadGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${baseName}'
  location: location
  tags: tags
}

module identities 'identidades.bicep' = {
  name: 'vex-bootstrap-identidades'
  scope: identityGroup
  params: {
    location: location
    baseName: baseName
    tags: tags
  }
}

module workload 'carga.bicep' = {
  name: 'vex-bootstrap-carga'
  scope: workloadGroup
  params: {
    deployPrincipalId: identities.outputs.deployPrincipalId
    kubeletPrincipalId: identities.outputs.kubeletPrincipalId
  }
}

// En el grupo de identidades y no en el de carga: quien es Contributor del
// grupo de una cuenta de almacenamiento puede reactivarle las llaves de cuenta.
module state 'estado.bicep' = {
  name: 'vex-bootstrap-estado'
  scope: identityGroup
  params: {
    location: location
    baseName: baseName
    tags: tags
    deployPrincipalId: identities.outputs.deployPrincipalId
  }
}

// En la suscripción y filtrado por grupos: quien solo es Contributor de esos
// grupos (la identidad de despliegue) no puede borrarlo ni cambiarlo.
resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (budgetAmount > 0) {
  name: baseName
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: [
          workloadGroup.name
          nodeGroupName
        ]
      }
    }
    notifications: {
      real80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: budgetEmails
      }
    }
  }
}

// --- Salidas del contrato azure/v1 -------------------------------------------
output deployIdentityId string = identities.outputs.deployIdentityId
output deployClientId string = identities.outputs.deployClientId
output deployPrincipalId string = identities.outputs.deployPrincipalId
output resourceGroup string = workloadGroup.name
output identityResourceGroup string = identityGroup.name
// La identidad `pull` del contrato es la del kubelet: con ella los nodos descargan las imágenes.
output pullIdentityId string = identities.outputs.kubeletIdentityId
output pullClientId string = identities.outputs.kubeletClientId
output stateAccount string = state.outputs.stateAccount
output stateContainer string = state.outputs.stateContainer

// --- Salidas propias: llegan a los pasos como VEX_BOOTSTRAP_<NOMBRE> ---------
output pullPrincipalId string = identities.outputs.kubeletPrincipalId
output aksIdentityId string = identities.outputs.aksIdentityId
output nodeResourceGroup string = nodeGroupName
