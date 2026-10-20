# Purpose
Runs the multiplayer demo on GCP: a GKE cluster named `multiplayer-demo` in zone `us-east1-b` with a `general` node pool, for Agones game servers and Open Match. It calls the [`modules/gcp/gke`](../../modules/gcp/gke/) child module.

# Cloud Provider Details
GCP Project: multiplayer-demo
GCP Region: us-east1
GCP VPC: multiplayer-demo-vpc (created by this configuration)

# Diagram
```mermaid
flowchart LR
  apis[Required project APIs] -.-> cluster
  admins([Admins in admin_cidrs]) --> cluster[GKE cluster multiplayer-demo]
  subgraph vpc[VPC multiplayer-demo-vpc]
    subnet[Subnet multiplayer-demo-subnet]
  end
  cluster --> pool[Node pool general]
  pool --> subnet
  sa[Node service account] -.-> pool
```

# Most Recent Changes

10/20/2026 - Added environment docs (#25 - CouchParty Games)
