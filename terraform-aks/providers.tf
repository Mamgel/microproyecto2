terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# usa la sesión de "az login"
# y la variable de entorno ARM_SUBSCRIPTION_ID.
provider "azurerm" {
  features {}
}
