terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "fraud_detection" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "FraudDetection"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_storage_account" "function_storage" {
  name                     = "stfraud${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.fraud_detection.name
  location                 = azurerm_resource_group.fraud_detection.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_eventhub_namespace" "transactions" {
  name                = "evh-transactions-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  location            = azurerm_resource_group.fraud_detection.location
  sku                 = "Standard"
  capacity            = 1
  tags                = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_eventhub" "transactions" {
  name                = "transactions"
  namespace_name      = azurerm_eventhub_namespace.transactions.name
  resource_group_name = azurerm_resource_group.fraud_detection.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_cosmosdb_account" "fraud_db" {
  name                = "cosmos-fraud-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  location            = azurerm_resource_group.fraud_detection.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.fraud_detection.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableServerless"
  }

  tags = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_cosmosdb_sql_database" "fraud_db" {
  name                = "FraudDB"
  resource_group_name = azurerm_cosmosdb_account.fraud_db.resource_group_name
  account_name        = azurerm_cosmosdb_account.fraud_db.name
}

resource "azurerm_cosmosdb_sql_container" "transactions" {
  name                = "Transactions"
  resource_group_name = azurerm_cosmosdb_account.fraud_db.resource_group_name
  account_name        = azurerm_cosmosdb_account.fraud_db.name
  database_name       = azurerm_cosmosdb_sql_database.fraud_db.name
  partition_key_path  = "/accountId"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "fraud_kv" {
  name                       = "kv-fraud-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.fraud_detection.name
  location                   = azurerm_resource_group.fraud_detection.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.fraud_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

resource "azurerm_key_vault_secret" "eventhub_connection" {
  name         = "EventHubConnection"
  value        = azurerm_eventhub_namespace.transactions.default_primary_connection_string
  key_vault_id = azurerm_key_vault.fraud_kv.id
  depends_on   = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "cosmosdb_connection" {
  name         = "CosmosDBConnection"
  value        = azurerm_cosmosdb_account.fraud_db.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.fraud_kv.id
  depends_on   = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_application_insights" "fraud_detection" {
  name                = "appi-fraud-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  location            = azurerm_resource_group.fraud_detection.location
  application_type    = "web"
  tags                = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_service_plan" "fraud_detection" {
  name                = "asp-fraud-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  location            = azurerm_resource_group.fraud_detection.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_linux_function_app" "fraud_detector" {
  name                       = "func-fraud-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.fraud_detection.name
  location                   = azurerm_resource_group.fraud_detection.location
  service_plan_id            = azurerm_service_plan.fraud_detection.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "18"
    }
    application_insights_connection_string = azurerm_application_insights.fraud_detection.connection_string
    application_insights_key               = azurerm_application_insights.fraud_detection.instrumentation_key
  }

  app_settings = {
    "EventHubConnection"       = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.fraud_kv.name};SecretName=EventHubConnection)"
    "CosmosDBConnection"       = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.fraud_kv.name};SecretName=CosmosDBConnection)"
    "FRAUD_THRESHOLD"          = var.fraud_threshold
    "VELOCITY_THRESHOLD"       = var.velocity_threshold
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  tags = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id       = azurerm_key_vault.fraud_kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_function_app.fraud_detector.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_monitor_action_group" "fraud_alerts" {
  name                = "ag-fraud-alerts"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  short_name          = "fraudalert"

  email_receiver {
    name          = "sendtoadmin"
    email_address = var.alert_email
  }

  tags = azurerm_resource_group.fraud_detection.tags
}

resource "azurerm_log_analytics_workspace" "fraud_detection" {
  name                = "law-fraud-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.fraud_detection.name
  location            = azurerm_resource_group.fraud_detection.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = azurerm_resource_group.fraud_detection.tags
}

output "resource_group_name" {
  value       = azurerm_resource_group.fraud_detection.name
  description = "Resource Group name"
}

output "function_app_name" {
  value       = azurerm_linux_function_app.fraud_detector.name
  description = "Function App name"
}

output "eventhub_namespace" {
  value       = azurerm_eventhub_namespace.transactions.name
  description = "Event Hub Namespace"
}

output "cosmosdb_account" {
  value       = azurerm_cosmosdb_account.fraud_db.name
  description = "Cosmos DB Account name"
}

output "key_vault_name" {
  value       = azurerm_key_vault.fraud_kv.name
  description = "Key Vault name"
}

output "function_app_url" {
  value       = "https://${azurerm_linux_function_app.fraud_detector.default_hostname}"
  description = "Function App URL"
}
