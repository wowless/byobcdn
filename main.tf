variable "bucket" {
  type = string
}

resource "google_service_account" "byobcdn-fetch-runner" {
  account_id   = "byobcdn-fetch-runner"
  display_name = "byobcdn-fetch-runner"
}

data "google_iam_policy" "byobcdn-fetch-runner" {}

resource "google_service_account_iam_policy" "byobcdn-fetch-runner" {
  policy_data        = data.google_iam_policy.byobcdn-fetch-runner.policy_data
  service_account_id = google_service_account.byobcdn-fetch-runner.name
}

resource "google_service_account" "byobcdn-tact-runner" {
  account_id   = "byobcdn-tact-runner"
  display_name = "byobcdn-tact-runner"
}

data "google_iam_policy" "byobcdn-tact-runner" {}

resource "google_service_account_iam_policy" "byobcdn-tact-runner" {
  policy_data        = data.google_iam_policy.byobcdn-tact-runner.policy_data
  service_account_id = google_service_account.byobcdn-tact-runner.name
}

resource "google_service_account" "byobcdn-watch-runner" {
  account_id   = "byobcdn-watch-runner"
  display_name = "byobcdn-watch-runner"
}

data "google_iam_policy" "byobcdn-watch-runner" {}

resource "google_service_account_iam_policy" "byobcdn-watch-runner" {
  policy_data        = data.google_iam_policy.byobcdn-watch-runner.policy_data
  service_account_id = google_service_account.byobcdn-watch-runner.name
}

data "google_iam_policy" "storage" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-fetch-runner.email}",
      "serviceAccount:${google_service_account.byobcdn-tact-runner.email}",
    ]
    role = "roles/storage.objectAdmin"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-watch-runner.email}",
    ]
    role = "roles/storage.objectViewer"
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
  max_instances         = 5
  timeout               = 5
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

data "google_iam_policy" "byobcdn-tact" {}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-tact" {
  cloud_function = google_cloudfunctions_function.byobcdn-tact.name
  policy_data    = data.google_iam_policy.byobcdn-tact.policy_data
}

resource "google_service_account" "byobcdn-root-runner" {
  account_id   = "byobcdn-root-runner"
  display_name = "byobcdn-root-runner"
}

data "google_iam_policy" "byobcdn-root-runner" {}

resource "google_service_account_iam_policy" "byobcdn-root-runner" {
  policy_data        = data.google_iam_policy.byobcdn-root-runner.policy_data
  service_account_id = google_service_account.byobcdn-root-runner.name
}

resource "google_pubsub_topic" "byobcdn-root" {
  name = "byobcdn-root"
}

data "google_iam_policy" "byobcdn-root-pubsub-topic" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-root-runner.email}",
    ]
    role = "roles/pubsub.publisher"
  }
}

resource "google_pubsub_topic_iam_policy" "byobcdn-root" {
  policy_data = data.google_iam_policy.byobcdn-root-pubsub-topic.policy_data
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

resource "google_cloud_scheduler_job" "byobcdn-root" {
  name             = "byobcdn-root"
  schedule         = "* * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "50s"
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.byobcdn-root.https_trigger_url
    oidc_token {
      audience              = google_cloudfunctions_function.byobcdn-root.https_trigger_url
      service_account_email = google_service_account.byobcdn-root-invoker.email
    }
  }
  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
    retry_count          = 0
  }
}

resource "google_cloudfunctions_function" "byobcdn-fetch" {
  name                  = "byobcdn-fetch"
  runtime               = "nodejs18"
  entry_point           = "function"
  available_memory_mb   = 128
  trigger_http          = true
  max_instances         = 5
  timeout               = 5
  service_account_email = google_service_account.byobcdn-fetch-runner.email
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

resource "google_service_account" "byobcdn-fetch-invoker" {
  account_id   = "byobcdn-fetch-invoker"
  display_name = "byobcdn-fetch-invoker"
}

data "google_iam_policy" "byobcdn-fetch-invoker" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-watch-runner.email}",
    ]
    role = "roles/iam.serviceAccountUser"
  }
}

resource "google_service_account_iam_policy" "byobcdn-fetch-invoker" {
  policy_data        = data.google_iam_policy.byobcdn-fetch-invoker.policy_data
  service_account_id = google_service_account.byobcdn-fetch-invoker.name
}

data "google_iam_policy" "byobcdn-fetch" {
  binding {
    members = [
      "serviceAccount:${google_service_account.byobcdn-fetch-invoker.email}",
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-fetch" {
  cloud_function = google_cloudfunctions_function.byobcdn-fetch.name
  policy_data    = data.google_iam_policy.byobcdn-fetch.policy_data
}

resource "google_cloudfunctions_function" "byobcdn-watch" {
  name                  = "byobcdn-watch"
  runtime               = "nodejs18"
  entry_point           = "watch"
  available_memory_mb   = 128
  service_account_email = google_service_account.byobcdn-watch-runner.email
  environment_variables = {
    BYOBCDN_BUCKET = var.bucket
  }
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = "projects/_/buckets/${var.bucket}"
    failure_policy {
      retry = true
    }
  }
  lifecycle {
    ignore_changes = [
      labels["deployment-tool"],
    ]
  }
  timeouts {}
}

data "google_iam_policy" "byobcdn-watch" {}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-watch" {
  cloud_function = google_cloudfunctions_function.byobcdn-watch.name
  policy_data    = data.google_iam_policy.byobcdn-watch.policy_data
}
