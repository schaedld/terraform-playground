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

# Create sample Ressource Group with the random uuid
resource "azurerm_resource_group" "rg"{
  name = "${uuid()}-rg"
  location = "switzerlandnorth"
}

# Create random numbers from 20 to 100 for the storageaccount
resource "random_integer" "randomint" {
  min = 10
  max = 99
}

# Create random name for the storage Account
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules
resource "random_string" "randomname" {
  length = 23
  special = false
  lower = true
  min_upper = 0 
  min_lower = 20
  min_numeric = 3
}


resource "azurerm_storage_account" "storageacc" {
  name                     = "${random_string.randomname.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [
    random_integer.randomint
  ]
}

resource "azurerm_mssql_server" "sqlsrv" {
  name                         = "sqlsrv-${random_integer.randomint.result}"
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
  tags = {
    environment = "test"
  }
}

# Database Configuartion
resource "azurerm_mssql_database" "sqldb" {
  name           = "bddtest-${random_integer.randomint.result}"
  server_id      = azurerm_mssql_server.sqlsrv.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 1
  read_scale     = false
  sku_name       = "Basic"
  zone_redundant = false  

  depends_on = [
    azurerm_mssql_server.sqlsrv
  ] 
}

# Create a random appservice plan.
resource "azurerm_app_service_plan" "bddtestplan" {
  name = "${random_string.randomname.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku {
    tier = "Standard"
    size = "S1"
  }
}

# Create random web app with the connection string retrived from the storageaccount
resource "azurerm_app_service" "bddtestappsvc" {
  name = "${random_string.randomname.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  app_service_plan_id = azurerm_app_service_plan.bddtestplan.id
  connection_string {
    name = "sample"
    type = "SQLServer"
    value = azurerm_storage_account.storageacc.primary_connection_string
  }
  depends_on = [
    azurerm_mssql_database.sqldb,
    azurerm_storage_account.storageacc,
    azurerm_app_service_plan.bddtestplan
  ]
}