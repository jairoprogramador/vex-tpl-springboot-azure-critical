terraform {
  required_providers {
    # Debe satisfacerlo el espejo de providers de la imagen de runtime.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.57.0"
    }
  }
}

# Tenant, suscripción, cliente y OIDC llegan por ARM_* (contrato azure/v1).
provider "azurerm" {
  features {}
  # Los espacios de nombres los registra `vex bootstrap` (providers: del manifiesto).
  resource_provider_registrations = "none"
}
