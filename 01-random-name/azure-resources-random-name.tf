# Base configuration
terraform {        
  required_providers {
      azurerm = {
          source = "hashicorp/azurerm"
          version = "2.74.0"
      }      
  }  
}

# Configure the Microsoft Azure Provider
provider "azurerm"{
  features {}
  # Wichtig, für die Verwendung der kleinstmöglichen Privilegien.
  skip_provider_registration = true
  subscription_id = ""
}

# uuid Ressource for name generation.
resource "random_uuid" "randomname"{

}

# Create sample Ressource Group with the random uuid
resource "azurerm_resource_group" "rg"{
  name = "${random_uuid.randomname.result}-rg"
  location = "switzerlandnorth"
}

# Create random numbers from 20 to 100 for the storageaccount
resource "random_integer" "randomint" {
  min = 10
  max = 99
}

resource "azurerm_storage_account" "storageacc" {
  name                     = "storageacc${random_integer.randomint.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [
    random_integer.randomint
  ]
}

resource "azurerm_mssql_server" "sqlsrv" {
  name                         = "${random_uuid.randomname.result}-sqlserver"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "missadministrator"
  administrator_login_password = "thisIsKat11"
  minimum_tls_version          = "1.2"

  extended_auditing_policy {
    storage_endpoint                        = azurerm_storage_account.storageacc.primary_blob_endpoint
    storage_account_access_key              = azurerm_storage_account.storageacc.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = 6
  }

  depends_on = [
    random_uuid.randomname
  ]

  tags = {
    environment = "test"
  }
}