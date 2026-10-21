# GCS bucket for the Terraform `gcs` backend of the root modules in this project.
#
# Locking: the gcs backend locks state natively. Before each write it creates
# `<prefix>/<workspace>.tflock` with a generation precondition, so a second run fails
# to take the lock until the first deletes it. No lock table is needed, but the bucket
# must let callers create and delete that object, which is why it has no retention
# policy (a retention policy would block deleting the lock and wedge every run).

locals {
  bucket_name = coalesce(var.bucket_name, "${var.project_id}-tfstate")
}

data "google_storage_project_service_account" "gcs" {
  count = var.kms_key_name == null ? 0 : 1
}

# The Cloud Storage service agent encrypts objects with the CMEK key, so it needs the
# key before the bucket is created.
resource "google_kms_crypto_key_iam_member" "gcs" {
  count = var.kms_key_name == null ? 0 : 1

  crypto_key_id = var.kms_key_name
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_storage_project_service_account.gcs[0].member
}

resource "google_storage_bucket" "state" {
  name     = local.bucket_name
  location = var.location

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # Versioning keeps earlier state files so a bad apply or corrupted state can be rolled back.
  versioning {
    enabled = true
  }

  # Only noncurrent versions expire; live state and lock objects are never touched.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_retention_days
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = var.kms_key_name == null ? [] : [var.kms_key_name]

    content {
      default_kms_key_name = encryption.value
    }
  }

  labels = var.labels

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs]
}

# roles/storage.objectUser covers what the backend needs to read and write state and to
# create and delete the lock object (storage.objects.get/list/create/delete).
resource "google_storage_bucket_iam_member" "state_users" {
  for_each = toset(var.state_users)

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectUser"
  member = each.value
}
