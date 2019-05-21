# This is an example of a basic Terraform configuration file that sets up a new demo resource group,
# creates a new demo network with a public and private subnet, and deploys an Azure Container Instance.

# IMPORTANT: Make sure subscription_id, client_id, client_secret, and tenant_id are configured!

# Configure the Azure Provider
provider "azurerm" {}

# Set remote backend for terraform state
terraform {
  backend "azurerm" {
    storage_account_name = "tfpipelinetest"
    container_name       = "tfdemo"
    key                  = "terraform.tfstate"
    access_key            = "__access_key__"
  }
}

# Create a resource group
resource "azurerm_resource_group" "devops_demo_resource_group" {
  name     = "devops_demo_resource_group"
  location = "westus2"

  tags {
    environment = "devops_demo"
    build       = "devops_demo"
  }
}

# Create a random ID for global name spaces
resource "random_id" "random_id" {
  keepers = {
    # Only generate a new ID if a new resource group is defined
    resource_group = "${azurerm_resource_group.devops_demo_resource_group.name}"
  }

  byte_length = 4
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "devops_demo_network" {
  name                = "devops_demo_network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.devops_demo_resource_group.location}"
  resource_group_name = "${azurerm_resource_group.devops_demo_resource_group.name}"

  subnet {
    name           = "devops_demo_public_subnet"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "devops_demo_private_subnet"
    address_prefix = "10.0.2.0/24"
  }

  tags {
    environment = "demo"
    build       = "devops_demo"
  }
}

# Create a storage account for ACI
resource "azurerm_storage_account" "devops_demo_storage_account" {
  name                = "devopsdemostorageaccount"
  resource_group_name = "${azurerm_resource_group.devops_demo_resource_group.name}"
  location            = "${azurerm_resource_group.devops_demo_resource_group.location}"
  account_tier        = "Standard"

  account_replication_type = "LRS"

  tags {
    environment = "demo"
    build       = "devops_demo"
  }
}

resource "azurerm_storage_share" "devops_demo_storage_share" {
  name = "devops-demo-storage-share"

  resource_group_name  = "${azurerm_resource_group.devops_demo_resource_group.name}"
  storage_account_name = "${azurerm_storage_account.devops_demo_storage_account.name}"

  quota = 50
}

resource "azurerm_container_group" "devops_demo_container_group" {
  name                = "devops_demo_container_group"
  resource_group_name = "${azurerm_resource_group.devops_demo_resource_group.name}"
  location            = "${azurerm_resource_group.devops_demo_resource_group.location}"
  ip_address_type     = "public"
  dns_name_label      = "devops-demo-${random_id.random_id.hex}"
  os_type             = "linux"

  container {
    name   = "devops-demo-hello-world"
    image  = "seanmckenna/aci-hellofiles"
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables {
      "NODE_ENV" = "demo"
    }

    volume {
      name       = "logs"
      mount_path = "/aci/logs"
      read_only  = false
      share_name = "${azurerm_storage_share.devops_demo_storage_share.name}"

      storage_account_name = "${azurerm_storage_account.devops_demo_storage_account.name}"
      storage_account_key  = "${azurerm_storage_account.devops_demo_storage_account.primary_access_key}"
    }
  }

  tags {
    environment = "demo"
    build       = "devops_demo"
  }
}
