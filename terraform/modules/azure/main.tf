resource "azurerm_resource_group" "aks" {
  name     = "${var.cluster_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "aks" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "aks-nodes"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.node_cidr]
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.cluster_name}-identity"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

# Grant subnet access before AKS starts provisioning its nodes.
resource "azurerm_role_assignment" "network" {
  scope                            = azurerm_subnet.nodes.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                              = var.cluster_name
  location                          = azurerm_resource_group.aks.location
  resource_group_name               = azurerm_resource_group.aks.name
  node_resource_group               = "${var.cluster_name}-nodes-rg"
  dns_prefix                        = var.cluster_name
  sku_tier                          = var.sku_tier
  automatic_upgrade_channel         = "stable"
  node_os_upgrade_channel           = "NodeImage"
  role_based_access_control_enabled = true
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  tags                              = var.tags

  default_node_pool {
    name                        = "system"
    temporary_name_for_rotation = "systemtemp"
    node_count                  = var.node_count
    vm_size                     = var.vm_size
    os_disk_size_gb             = var.disk_size_gb
    os_disk_type                = "Managed"
    os_sku                      = "Ubuntu"
    vnet_subnet_id              = azurerm_subnet.nodes.id
    node_public_ip_enabled      = false
    max_pods                    = 110
    zones                       = var.availability_zones
    tags                        = var.tags

    upgrade_settings {
      max_surge = "1"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = false
  }

  api_server_access_profile {
    authorized_ip_ranges = var.admin_cidrs
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"

    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  depends_on = [azurerm_role_assignment.network]
}
