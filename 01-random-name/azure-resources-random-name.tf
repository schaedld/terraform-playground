## Konfiguration für die .NET UserGroup Entwicklungs-Umgebung
terraform {
  required_providers {
      azurerm = {
          source = "hashicorp/azurerm"
          version = "=2.74.0"
      }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm"{
  features {}
  # Wichtig, für die Verwendung der kleinstmöglichen Privilegien.
  skip_provider_registration = true
  subscription_id = "a40a25f3-5cee-4b4d-8a16-362b37856e94"
}

# Create random resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${uuid()}"
  location = "switzerlandnorth"
}

# Random integer
resource "random_integer" "randomint" {
 min = 1
 max = 99 
}

# Random string for the storageaccount
resource "random_string" "randomstring" {  
  length = 21
  special = false
  min_lower = 19
  min_upper = 0
  min_numeric = 2
}

resource "azurerm_storage_account" "storageacc" {
  name                     = "${random_string.randomstring.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

# Create the sql server with a random integer as postfix.
resource "azurerm_sql_server" "sqlsrv" {
  name                         = "bddtestsql-${random_integer.randomint.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "mradministrator"
  administrator_login_password = "thisIsDog11"

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

# Create the database
resource "azurerm_mssql_database" "bddtestdb" {
  name           = "bddtestdb-${random_integer.randomint.result}"
  server_id      = azurerm_sql_server.sqlsrv.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 1
  read_scale     = false
  sku_name       = "Basic"
  zone_redundant = false

  extended_auditing_policy {
    storage_endpoint                        = azurerm_storage_account.storageacc.primary_blob_endpoint
    storage_account_access_key              = azurerm_storage_account.storageacc.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = 6
  }

  tags = {
    foo = "test-db"
  }
}

# Create the web app service plan with the postfix of the random integer
resource "azurerm_app_service_plan" "appsvcplan" {
  name                = "appserviceplan-${random_integer.randomint.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# Create the web app service with the postfix of the random integer
resource "azurerm_app_service" "appsvc" {
  name                = "bddtest-app-service-${random_integer.randomint.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appsvcplan.id

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }


  connection_string {
    name  = "Sample"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_sql_server.sqlsrv.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.bddtestdb.name};Persist Security Info=False;User ID=${azurerm_sql_server.sqlsrv.administrator_login};Password=${azurerm_sql_server.sqlsrv.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }

  depends_on = [
    azurerm_app_service_plan.appsvcplan,
    azurerm_sql_server.sqlsrv
  ]
}
