# Unit tests with a mocked AzureRM provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/azure test`.

mock_provider "azurerm" {}

variables {
  subscription_id        = "00000000-0000-0000-0000-000000000000"
  admin_cidrs            = ["203.0.113.10/32"]
  admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].dns_service_ip == "10.60.0.10"
    error_message = "DNS should use address 10 of service_cidr."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_plugin_mode == "overlay"
    error_message = "The cluster should use Azure CNI overlay."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.api_server_access_profile[0].authorized_ip_ranges == toset(var.admin_cidrs)
    error_message = "The API server should only allow admin_cidrs."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.local_account_disabled
    error_message = "Local accounts should be disabled so access goes through Entra ID."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].node_public_ip_enabled == false
    error_message = "Nodes should not get public IPs."
  }

  assert {
    condition     = azurerm_resource_group.aks.name == "multiplayer-demo-rg"
    error_message = "Resource names should be prefixed with cluster_name."
  }
}

run "custom_service_cidr" {
  command = plan

  variables {
    service_cidr = "10.61.0.0/24"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].dns_service_ip == "10.61.0.10"
    error_message = "DNS should follow service_cidr."
  }
}

run "rejects_service_cidr_without_dns_address" {
  command = plan

  variables {
    service_cidr = "10.60.0.0/29"
  }

  expect_failures = [var.service_cidr]
}

run "rejects_open_admin_cidr" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "rejects_non_uuid_admin_group" {
  command = plan

  variables {
    admin_group_object_ids = ["aks-admins"]
  }

  expect_failures = [var.admin_group_object_ids]
}

run "rejects_unknown_zone" {
  command = plan

  variables {
    availability_zones = ["1", "4"]
  }

  expect_failures = [var.availability_zones]
}

run "rejects_unknown_sku_tier" {
  command = plan

  variables {
    sku_tier = "Premium"
  }

  expect_failures = [var.sku_tier]
}

run "rejects_small_disk" {
  command = plan

  variables {
    disk_size_gb = 20
  }

  expect_failures = [var.disk_size_gb]
}
