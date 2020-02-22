############################################################
# VARIABLES
############################################################

variable "location" {
  type    = string
  default = "eastus2"
}

variable "agents_size" {
  type    = string
  default = "Standard_B2s"
}

variable "prefix" {
  type    = string
  default = "vault"
}

############################################################
# PROVIDERS
############################################################

provider "azurerm" {}

provider "azuread" {}

############################################################
# DATA SOURCES
############################################################

data "azurerm_subscription" "primary" {
}

# Get the current available version of Kubernetes on AKS

data "azurerm_kubernetes_service_versions" "current" {
  location = var.location
}

# Create the yaml files for the vault-msi Azure Identity

data "template_file" "aadpodidentity_vault" {
  template = file("${path.module}/template_files/aadpodidentity.tpl")
  vars = {
    msi_name        = "vault-msi"
    msi_resource_id = azurerm_user_assigned_identity.vault_msi.id
    msi_client_id   = azurerm_user_assigned_identity.vault_msi.client_id
  }
}

data "template_file" "aadpodidentitybinding_vault" {
  template = file("${path.module}/template_files/aadpodidentitybinding.tpl")
  vars = {
    msi_name = "vault-msi"
    label = "vault"
  }
}

# Create the yaml files for the demo-msi Azure Identity

data "template_file" "aadpodidentity_demo" {
  template = file("${path.module}/template_files/aadpodidentity.tpl")
  vars = {
    msi_name        = "demo-msi"
    msi_resource_id = azurerm_user_assigned_identity.demo_msi.id
    msi_client_id   = azurerm_user_assigned_identity.demo_msi.client_id
  }
}

data "template_file" "aadpodidentitybinding_demo" {
  template = file("${path.module}/template_files/aadpodidentitybinding.tpl")
  vars = {
    msi_name = "demo-msi"
    label = "demo"
  }
}

############################################################
# RESOURCES
############################################################

# Create the service principal for the AKS Cluster

resource "random_password" "aks_sp" {
  length  = 16
  special = false
}

resource "azuread_application" "aks_sp" {
  name = "aks-sp"
}

resource "azuread_service_principal" "aks_sp" {
  application_id = azuread_application.aks_sp.application_id
}

resource "azuread_service_principal_password" "aks_sp" {
  service_principal_id = azuread_service_principal.aks_sp.id
  value                = random_password.aks_sp.result
  end_date_relative    = "17520h"
}

# Create the AKS cluster

resource "azurerm_resource_group" "aks" {
  name     = "${var.prefix}-aks"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "vault" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.prefix
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version

  default_node_pool {
    name               = "default"
    node_count         = 3
    vm_size            = var.agents_size
    type               = "VirtualMachineScaleSets"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  service_principal {
    client_id     = azuread_service_principal.aks_sp.application_id
    client_secret = random_password.aks_sp.result
  }

  tags = {
    Environment = "vault"
  }
}

# Create the vault and demo Azure Identities

resource "azurerm_user_assigned_identity" "vault_msi" {
  resource_group_name = azurerm_kubernetes_cluster.vault.node_resource_group
  location            = azurerm_resource_group.aks.location

  name = "vault-msi"
}

resource "azurerm_user_assigned_identity" "demo_msi" {
  resource_group_name = azurerm_kubernetes_cluster.vault.node_resource_group
  location            = azurerm_resource_group.aks.location

  name = "demo-msi"
}

# Give the vault msi a custom role on the AKS resource group

resource "azurerm_role_definition" "vault-role" {
  name               = "vault-azure-auth"
  scope              = data.azurerm_subscription.primary.id

  permissions {
    actions     = ["Microsoft.Compute/virtualMachines/*/read", "Microsoft.Compute/virtualMachineScaleSets/*/read"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.primary.id,
  ]
}

resource "azurerm_role_assignment" "vault-role-assignment" {
  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${azurerm_kubernetes_cluster.vault.node_resource_group}"
  role_definition_id = azurerm_role_definition.vault-role.id
  principal_id       = azurerm_user_assigned_identity.vault_msi.principal_id
}

# Write the yaml templates out to files for both Azure Identities

resource "local_file" "aadpodidentity_vault" {
  content = data.template_file.aadpodidentity_vault.rendered

  filename = "${path.module}/yaml_files/aadpodidentity-vault.yaml"
}

resource "local_file" "aadpodidentitybinding_vault" {
  content = data.template_file.aadpodidentitybinding_vault.rendered

  filename = "${path.module}/yaml_files/aadpodidentitybinding-vault.yaml"
}


resource "local_file" "aadpodidentity_demo" {
  content = data.template_file.aadpodidentity_demo.rendered

  filename = "${path.module}/yaml_files/aadpodidentity-demo.yaml"
}

resource "local_file" "aadpodidentitybinding_demo" {
  content = data.template_file.aadpodidentitybinding_demo.rendered

  filename = "${path.module}/yaml_files/aadpodidentitybinding-demo.yaml"
}

############################################################
# RESOURCES
############################################################

output "subscription_id" {
  value = data.azurerm_subscription.primary.id
}

output "aks_resource_group" {
  value = azurerm_kubernetes_cluster.vault.node_resource_group
}
