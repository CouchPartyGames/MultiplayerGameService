# Unit tests with a mocked AWS provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/aws test`.

mock_provider "aws" {
  # The provider validates policy ARNs, so the partition must be a real one.
  override_data {
    target = data.aws_partition.current
    values = {
      partition = "aws"
    }
  }

  # Unsorted on purpose: the configuration sorts zones before taking the first two.
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1c", "us-east-1a", "us-east-1b"]
    }
  }
}

variables {
  admin_cidrs          = ["203.0.113.10/32"]
  admin_principal_arns = ["arn:aws:iam::123456789012:role/admin"]
}

run "defaults" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.eks) == 1
    error_message = "single_nat_gateway = true should create one NAT gateway."
  }

  assert {
    condition     = join(",", [for s in aws_subnet.public : s.availability_zone]) == "us-east-1a,us-east-1b"
    error_message = "Subnets should use the first two zones in sorted order."
  }

  assert {
    condition     = join(",", aws_subnet.public[*].cidr_block) == "10.70.0.0/20,10.70.16.0/20"
    error_message = "Public subnets should be the first two /20s of the VPC."
  }

  assert {
    condition     = join(",", aws_subnet.private[*].cidr_block) == "10.70.128.0/20,10.70.144.0/20"
    error_message = "Private subnets should start at the ninth /20 of the VPC."
  }

  assert {
    condition     = aws_eks_cluster.eks.vpc_config[0].public_access_cidrs == toset(var.admin_cidrs)
    error_message = "The public API endpoint should only allow admin_cidrs."
  }

  assert {
    condition     = aws_eks_cluster.eks.access_config[0].bootstrap_cluster_creator_admin_permissions == false
    error_message = "Cluster admin access should come only from admin_principal_arns."
  }

  assert {
    condition     = toset(keys(aws_eks_access_policy_association.admins)) == var.admin_principal_arns
    error_message = "Each admin principal should get a cluster admin policy association."
  }

  assert {
    condition     = aws_eks_node_group.general.scaling_config[0].desired_size == 3
    error_message = "The node group should default to three nodes."
  }
}

run "nat_gateway_per_zone" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.eks) == 2 && length(aws_eip.nat) == 2
    error_message = "single_nat_gateway = false should create a NAT gateway and EIP per zone."
  }
}

run "rejects_invalid_cluster_name" {
  command = plan

  variables {
    cluster_name = "Multiplayer_Demo"
  }

  expect_failures = [var.cluster_name]
}

run "rejects_non_16_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.70.0.0/20"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_open_admin_cidr" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "rejects_assumed_role_session_arn" {
  command = plan

  variables {
    admin_principal_arns = ["arn:aws:sts::123456789012:assumed-role/admin/session"]
  }

  expect_failures = [var.admin_principal_arns]
}

run "rejects_min_above_desired" {
  command = plan

  variables {
    node_scaling = { desired = 1, min = 2, max = 5 }
  }

  expect_failures = [var.node_scaling]
}

run "rejects_small_disk" {
  command = plan

  variables {
    disk_size_gb = 10
  }

  expect_failures = [var.disk_size_gb]
}
