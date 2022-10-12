terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.26.0"
    }
  }
  required_version = "~> 1.3.0"

  /* Comment this block when deploying this storage for the first time
  After that leave it uncommented.
  TF needs to create storage first and then setup remote backend
  by "terraform init"  */
  backend "azurerm" {
    resource_group_name  = "lifeboardtfstate"
    storage_account_name = "lifeboardtfstate"
    container_name       = "data"
    key                  = "tf_storage.tfstate"
  }
}

provider "azurerm" {
  features {
  }
}

locals {
  tags = {
    environment = "${var.environment}"
    project     = "${var.project_name}"
    source      = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = format("%stfstate", var.project_name)
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "this" {
  name                      = format("%stfstate", var.project_name)
  resource_group_name       = azurerm_resource_group.this.name
  location                  = azurerm_resource_group.this.location
  account_tier              = "Standard"
  access_tier               = "Hot"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  is_hns_enabled            = true
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  tags                      = local.tags
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}
