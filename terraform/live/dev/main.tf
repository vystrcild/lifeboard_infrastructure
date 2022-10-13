terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = "~> 1.3.0"

  backend "azurerm" {
    resource_group_name  = "lifeboardtfstate"
    storage_account_name = "lifeboardtfstate"
    container_name       = "data"
    key                  = "dev.tfstate"
  }
}

provider "azurerm" {
  features {
  }
}

provider "random" {
}

locals {
  tags = {
    environment = "${var.environment}"
    project     = "${var.project_name}"
    source      = "terraform"
  }
  name_prefix = format("%s-%s-", var.environment, var.project_name)
}

resource "azurerm_resource_group" "this" {
  name     = format("%srg", local.name_prefix)
  location = var.location
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# KeyVault
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = format("%skv", local.name_prefix)
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  sku_name                   = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set"
    ]
  }
  tags = local.tags
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

resource "random_id" "username" {
  byte_length = 10
}

resource "random_password" "password" {
  length  = 10
  special = true
}

resource "azurerm_key_vault_secret" "db_un" {
  name         = format("%sdb-un", local.name_prefix)
  value        = random_id.username.hex
  key_vault_id = azurerm_key_vault.this.id
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "db_pw" {
  name         = format("%sdb-pass", local.name_prefix)
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.this.id
  tags         = local.tags
}

resource "azurerm_mssql_server" "this" {
  name                                 = format("%ssqlserver", local.name_prefix)
  resource_group_name                  = azurerm_resource_group.this.name
  location                             = azurerm_resource_group.this.location
  version                              = "12.0"
  administrator_login                  = azurerm_key_vault_secret.db_un.value
  administrator_login_password         = azurerm_key_vault_secret.db_pw.value
  tags                                 = local.tags
  outbound_network_restriction_enabled = false
}

resource "azurerm_mssql_database" "this" {
  name        = format("%sdb", local.name_prefix)
  server_id   = azurerm_mssql_server.this.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb = 2
  sku_name    = "Basic"
  tags        = local.tags
}

resource "azurerm_mssql_firewall_rule" "this" {
  name             = "Home"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "78.45.130.29"
  end_ip_address   = "78.45.130.29"
} //TODO: Vyhodit do variables a ty hodit do gitignore


output "sql_server" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

//TODO:Cost alert
