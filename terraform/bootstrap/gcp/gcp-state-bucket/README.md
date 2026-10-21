# GCP state bucket bootstrap

Creates the Cloud Storage bucket that holds Terraform state for the GCP root modules in `envs/`, which use the `gcs` backend. It creates:

| Resource | Purpose |
| --- | --- |
| `google_storage_bucket.state` | The state bucket: versioned, uniform bucket-level access, public access prevention enforced, noncurrent versions deleted after `noncurrent_version_retention_days`. Sets `prevent_destroy`. |
| `google_storage_bucket_iam_member.state_users` | Grants each member in `state_users` `roles/storage.objectUser`, enough to read, write, and lock state. |
| `google_kms_crypto_key_iam_member.gcs` | Only with `kms_key_name`: lets the project's Cloud Storage service agent use the key for CMEK. |

## State locking

The `gcs` backend locks state natively, with no extra lock table. Before writing state it creates `<prefix>/<workspace>.tflock` in the bucket with a precondition that the object does not exist, and deletes it when done; a second run that finds the lock fails with `Error acquiring the state lock`. Locking is on by default and stays on unless a run passes `-lock=false`, which you should not do.

For locking to work, this module keeps the bucket free of anything that blocks creating or deleting the lock object:

- No retention policy or object holds: they would stop the lock from being deleted and block every later run.
- The lifecycle rule deletes only noncurrent (archived) versions, never live state or lock files.
- Every identity that runs Terraform needs `storage.objects.create` and `storage.objects.delete` on the bucket; `state_users` grants them through `roles/storage.objectUser`.

If a run crashes and leaves a lock behind, release it with `terraform force-unlock <lock-id>` from the affected root module, using the ID from the error message.

## Apply

This is a bootstrap root module (see [Bootstrap](../../../README.md#bootstrap)): apply it once per project with your own credentials (for example `gcloud auth application-default login`), with local state. It is not an Atlantis project or CI matrix entry.

1. Copy the example variables and set `project_id`, and `state_users` for the identities that run Terraform:

   ```bash
   cp terraform/bootstrap/gcp/gcp-state-bucket/terraform.tfvars.example terraform/bootstrap/gcp/gcp-state-bucket/terraform.tfvars
   ```

2. Plan and apply:

   ```bash
   terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket init
   terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket plan -out=tfplan
   terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket apply tfplan
   ```

3. Move this module's own state into the bucket it created. Add a backend block to `versions.tf`:

   ```hcl
   terraform {
     backend "gcs" {
       bucket = "multiplayer-demo-tfstate"
       prefix = "bootstrap/gcp-state-bucket"
     }
   }
   ```

   Then migrate and delete the local state file:

   ```bash
   terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket init -migrate-state
   rm terraform/bootstrap/gcp/gcp-state-bucket/terraform.tfstate*
   ```

4. Point each GCP root module's `backend "gcs"` block at the bucket (the `backend_config` output prints one), giving each module its own `prefix`, then run `init -migrate-state` there too.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project_id` | `string` | required | Project that owns the bucket; also the provider's project. |
| `bucket_name` | `string` | `null` | Globally unique bucket name. Null uses `<project_id>-tfstate`. |
| `location` | `string` | `"US-EAST1"` | Region, dual-region, or multi-region, in upper case. |
| `noncurrent_version_retention_days` | `number` | `90` | Days to keep a replaced state version. |
| `kms_key_name` | `string` | `null` | Cloud KMS key for CMEK. Null uses Google-managed encryption. |
| `state_users` | `list(string)` | `[]` | Members granted `roles/storage.objectUser`, such as `serviceAccount:atlantis@<project>.iam.gserviceaccount.com`. |
| `labels` | `map(string)` | `{}` | Extra bucket labels, merged with the provider's default labels. |

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | Bucket name, for the backend's `bucket` argument. |
| `bucket_url` | `gs://` URL of the bucket. |
| `backend_config` | A `backend "gcs"` block to paste into a root module. |

## Tests

```bash
terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket init -backend=false
terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket test
```
