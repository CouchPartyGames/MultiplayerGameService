# Unit tests with a mocked Google provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/bootstrap/gcp/gcp-state-bucket test`.

mock_provider "google" {
  mock_data "google_storage_project_service_account" {
    defaults = {
      member = "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id = "multiplayer-demo"
}

run "defaults" {
  command = plan

  assert {
    condition     = google_storage_bucket.state.name == "multiplayer-demo-tfstate" && google_storage_bucket.state.location == "US-EAST1"
    error_message = "The bucket should default to <project_id>-tfstate in US-EAST1."
  }

  assert {
    condition     = google_storage_bucket.state.versioning[0].enabled
    error_message = "Versioning should be enabled so earlier state can be restored."
  }

  assert {
    condition     = google_storage_bucket.state.uniform_bucket_level_access && google_storage_bucket.state.public_access_prevention == "enforced"
    error_message = "The bucket should use uniform access and block public access."
  }

  assert {
    condition     = length(google_storage_bucket.state.retention_policy) == 0
    error_message = "A retention policy would stop the backend deleting its lock object."
  }

  assert {
    condition     = alltrue([for c in google_storage_bucket.state.lifecycle_rule[0].condition : c.with_state == "ARCHIVED"])
    error_message = "The lifecycle rule should delete only noncurrent versions, never live state or locks."
  }

  assert {
    condition     = length(google_storage_bucket.state.encryption) == 0 && length(google_kms_crypto_key_iam_member.gcs) == 0
    error_message = "Without a KMS key, the bucket should use Google-managed encryption."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.state_users) == 0
    error_message = "No IAM bindings should be created by default."
  }
}

run "cmek_and_users" {
  command = plan

  variables {
    bucket_name  = "custom-tfstate"
    kms_key_name = "projects/multiplayer-demo/locations/us-east1/keyRings/tf/cryptoKeys/state"
    state_users  = ["serviceAccount:atlantis@multiplayer-demo.iam.gserviceaccount.com"]
  }

  assert {
    condition     = google_storage_bucket.state.name == "custom-tfstate"
    error_message = "bucket_name should override the default name."
  }

  assert {
    condition     = google_storage_bucket.state.encryption[0].default_kms_key_name == "projects/multiplayer-demo/locations/us-east1/keyRings/tf/cryptoKeys/state"
    error_message = "The bucket should encrypt with the given KMS key."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.gcs[0].member == "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    error_message = "The Cloud Storage service agent should get access to the KMS key."
  }

  assert {
    condition     = google_storage_bucket_iam_member.state_users["serviceAccount:atlantis@multiplayer-demo.iam.gserviceaccount.com"].role == "roles/storage.objectUser"
    error_message = "State users should get roles/storage.objectUser so they can take the lock."
  }
}

run "rejects_bad_bucket_name" {
  command = plan

  variables {
    bucket_name = "Bad_Name."
  }

  expect_failures = [var.bucket_name]
}

run "rejects_lowercase_location" {
  command = plan

  variables {
    location = "us-east1"
  }

  expect_failures = [var.location]
}

run "rejects_member_without_type" {
  command = plan

  variables {
    state_users = ["atlantis@multiplayer-demo.iam.gserviceaccount.com"]
  }

  expect_failures = [var.state_users]
}
