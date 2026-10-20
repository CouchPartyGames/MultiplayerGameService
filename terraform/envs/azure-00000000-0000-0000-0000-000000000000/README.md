# Purpose
Runs the multiplayer demo on Azure: an AKS cluster named `multiplayer-demo` for Agones game servers and Open Match. It calls the [`modules/azure/aks`](../../modules/azure/aks/) child module.

# Cloud Provider Details
Azure Subscription: 00000000-0000-0000-0000-000000000000
Azure Region: eastus
Azure VNet: multiplayer-demo-vnet (created by this configuration in resource group `multiplayer-demo-rg`)

# Diagram
```mermaid
flowchart LR
  admins([Admins in admin_cidrs]) --> api[AKS API server]
  subgraph rg[Resource group multiplayer-demo-rg]
    subgraph vnet[VNet multiplayer-demo-vnet]
      subnet[Subnet aks-nodes]
    end
    identity[User-assigned identity] -- Network Contributor --> subnet
    api --> cluster[AKS cluster multiplayer-demo]
    identity -.-> cluster
  end
  cluster --> subnet
```

# Most Recent Changes

10/20/2026 - Added environment docs (#TBD - CouchParty Games)
