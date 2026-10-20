# Unit tests with a mocked Google provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/modules/gcp/gke test`.

mock_provider "google" {}

variables {
  project_id  = "demo-project"
  admin_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
}

run "defaults" {
  command = plan

  assert {
    condition     = length(google_compute_firewall.agones) == 0
    error_message = "The Agones UDP rule should be off by default."
  }

  assert {
    condition     = google_container_cluster.gke.deletion_protection
    error_message = "Deletion protection should be on by default."
  }

  assert {
    condition     = google_container_cluster.gke.workload_identity_config[0].workload_pool == "demo-project.svc.id.goog"
    error_message = "The workload pool should be derived from project_id."
  }

  assert {
    condition = toset([
      for b in google_container_cluster.gke.master_authorized_networks_config[0].cidr_blocks : b.cidr_block
    ]) == toset(var.admin_cidrs)
    error_message = "The API should only allow admin_cidrs."
  }

  assert {
    condition     = google_container_node_pool.general.node_config[0].tags == tolist(["multiplayer-demo-node"])
    error_message = "Nodes should carry the tag the Agones firewall rule targets."
  }

  assert {
    condition     = google_container_node_pool.general.node_count == 3
    error_message = "The node pool should default to three nodes."
  }
}

run "agones_udp_enabled" {
  command = plan

  variables {
    enable_agones_udp = true
    game_client_cidrs = ["192.0.2.0/24"]
  }

  assert {
    condition     = length(google_compute_firewall.agones) == 1
    error_message = "enable_agones_udp = true should create the firewall rule."
  }

  assert {
    condition     = google_compute_firewall.agones[0].target_tags == toset(google_container_node_pool.general.node_config[0].tags)
    error_message = "The firewall rule should target the node pool's tag."
  }

  assert {
    condition     = google_compute_firewall.agones[0].source_ranges == toset(["192.0.2.0/24"])
    error_message = "The firewall rule should allow only game_client_cidrs."
  }

  assert {
    condition = anytrue([
      for a in google_compute_firewall.agones[0].allow : a.protocol == "udp" && a.ports == tolist(["7000-8000"])
    ])
    error_message = "The firewall rule should allow UDP 7000-8000."
  }
}

run "rejects_long_cluster_name" {
  command = plan

  variables {
    cluster_name = "multiplayer-demo-cluster1"
  }

  expect_failures = [var.cluster_name]
}

run "rejects_open_admin_cidr" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "rejects_zero_nodes" {
  command = plan

  variables {
    node_count = 0
  }

  expect_failures = [var.node_count]
}

run "rejects_invalid_game_client_cidr" {
  command = plan

  variables {
    game_client_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.game_client_cidrs]
}
