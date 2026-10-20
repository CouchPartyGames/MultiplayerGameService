<!--
Template for terraform/envs/<cloud>-<id>/README.md. Keep the four top-level
headings exactly as written and in this order; scripts/env-docs-check.sh
enforces them. Replace every <placeholder>.

Cloud Provider Details keys, by directory prefix:
  aws-    AWS Account, AWS Region, AWS VPC
  azure-  Azure Subscription, Azure Region, Azure VNet
  gcp-    GCP Project, GCP Region, GCP VPC

Changelog lines: MM/DD/YYYY - <Summary> (#<PR> - <Author>), newest first.
Write #TBD until the PR exists, then replace it with the PR number.
-->
# Purpose
<What this environment is for and what it runs, in 1-3 sentences.>

# Cloud Provider Details
AWS Account: <account ID>
AWS Region: <region>
AWS VPC: <VPC ID or name, or "Created by this configuration (`module.<name>.vpc_id`)">

# Diagram
```mermaid
flowchart LR
  <resources this environment creates and how they connect>
```

# Most Recent Changes

<MM/DD/YYYY> - <Summary> (#<PR> - <Author>)
