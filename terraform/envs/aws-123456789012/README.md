# Purpose
Runs the multiplayer demo on AWS: an EKS cluster named `multiplayer-demo` with a managed `general` node group, for Agones game servers and Open Match. It calls the [`modules/aws/eks`](../../modules/aws/eks/) child module.

# Cloud Provider Details
AWS Account: 123456789012
AWS Region: us-east-1
AWS VPC: Created by this configuration (`module.eks.vpc_id`)

# Diagram
```mermaid
flowchart LR
  admins([Admins in admin_cidrs]) --> api[EKS API endpoint]
  subgraph vpc[VPC]
    subgraph public[Public subnets x2]
      nat[NAT gateway]
    end
    subgraph private[Private subnets x2]
      nodes[Node group: general]
    end
  end
  igw[Internet gateway] --- public
  nodes --> nat --> igw
  api --> cluster[EKS cluster multiplayer-demo]
  cluster --> nodes
  cluster --> logs[CloudWatch log group]
  iam[IAM roles: cluster, nodes] -.-> cluster
  iam -.-> nodes
```

# Most Recent Changes

10/20/2026 - Added environment docs (#25 - CouchParty Games)
