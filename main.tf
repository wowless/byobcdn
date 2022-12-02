variable "bucket" {
  type = string
}

resource "google_service_account" "byobcdn-tact-runner" {
  account_id   = "byobcdn-tact-runner"
  display_name = "byobcdn-tact-runner"
}

data "google_iam_policy" "storage" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-tact-runner.email}",
    ]
    role = "roles/storage.objectAdmin"
  }
}

resource "google_storage_bucket" "storage" {
  name                        = var.bucket
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_policy" "storage" {
  bucket      = google_storage_bucket.storage.name
  policy_data = data.google_iam_policy.storage.policy_data
}

resource "google_cloudfunctions_function" "byobcdn-tact" {
  name                  = "byobcdn-tact"
  runtime               = "nodejs18"
  entry_point           = "function"
  available_memory_mb   = 128
  trigger_http          = true
  service_account_email = google_service_account.byobcdn-tact-runner.email
  environment_variables = {
    BYOBCDN_BUCKET = var.bucket
  }
  lifecycle {
    ignore_changes = [
      labels["deployment-tool"],
    ]
  }
  timeouts {}
}

resource "google_service_account" "byobcdn-tact-invoker" {
  account_id   = "byobcdn-tact-invoker"
  display_name = "byobcdn-tact-invoker"
}

data "google_iam_policy" "byobcdn-tact-invoker" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-tact-runner.email}",
    ]
    role = "roles/iam.serviceAccountUser"
  }
}

resource "google_service_account_iam_policy" "byobcdn-tact-invoker" {
  service_account_id = google_service_account.byobcdn-tact-invoker.name
  policy_data        = data.google_iam_policy.byobcdn-tact-invoker.policy_data
}

data "google_iam_policy" "byobcdn-tact" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-tact-invoker.email}",
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-tact" {
  cloud_function = google_cloudfunctions_function.byobcdn-tact.name
  policy_data    = data.google_iam_policy.byobcdn-tact.policy_data
}

resource "google_service_account" "byobcdn-root-runner" {
  account_id   = "byobcdn-root-runner"
  display_name = "byobcdn-root-runner"
}

resource "google_pubsub_topic" "byobcdn-root" {
  name = "byobcdn-root"
}

data "google_iam_policy" "byobcdn-root-pubsub" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-root-runner.email}",
    ]
    role = "roles/pubsub.publisher"
  }
}

resource "google_pubsub_topic_iam_policy" "byobcdn-root" {
  policy_data = data.google_iam_policy.byobcdn-root-pubsub.policy_data
  topic       = google_pubsub_topic.byobcdn-root.name
}

resource "google_cloudfunctions_function" "byobcdn-root" {
  name                  = "byobcdn-root"
  runtime               = "nodejs18"
  entry_point           = "function"
  available_memory_mb   = 128
  trigger_http          = true
  service_account_email = google_service_account.byobcdn-root-runner.email
  lifecycle {
    ignore_changes = [
      labels["deployment-tool"],
    ]
  }
  timeouts {}
}

resource "google_service_account" "byobcdn-root-invoker" {
  account_id   = "byobcdn-root-invoker"
  display_name = "byobcdn-root-invoker"
}

data "google_iam_policy" "byobcdn-root-invoker" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-root-runner.email}",
    ]
    role = "roles/iam.serviceAccountUser"
  }
}

resource "google_service_account_iam_policy" "byobcdn-root-invoker" {
  service_account_id = google_service_account.byobcdn-root-invoker.name
  policy_data        = data.google_iam_policy.byobcdn-root-invoker.policy_data
}

data "google_iam_policy" "byobcdn-root" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-root-invoker.email}",
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-root" {
  cloud_function = google_cloudfunctions_function.byobcdn-root.name
  policy_data    = data.google_iam_policy.byobcdn-root.policy_data
}
