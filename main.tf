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
      google_service_account.byobcdn-fetch-runner.member,
      google_service_account.byobcdn-tact-runner.member,
    ]
    role = "roles/storage.objectAdmin"
  }
  binding {
    members = [
      google_service_account.byobcdn-process-runner.member,
      google_service_account.byobcdn-watch-runner.member,
      google_service_account.byobcdn-www-runner.member,
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
      google_service_account.byobcdn-root-runner.member,
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
      google_service_account.byobcdn-root-runner.member,
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
      google_service_account.byobcdn-root-invoker.member,
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
  available_memory_mb   = 4096
  trigger_http          = true
  max_instances         = 5
  timeout               = 120
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
      google_service_account.byobcdn-process-runner.member,
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
      google_service_account.byobcdn-fetch-invoker.member,
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
    BYOBCDN_PROCESS_ENDPOINT = google_cloudfunctions_function.byobcdn-process.https_trigger_url
    BYOBCDN_PROCESS_INVOKER  = google_service_account.byobcdn-process-invoker.email
    BYOBCDN_PROCESS_QUEUE    = google_cloud_tasks_queue.byobcdn-process.id
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

resource "google_cloud_tasks_queue" "byobcdn-fetch" {
  name     = "byobcdn-fetch"
  location = "us-central1"
}

data "google_iam_policy" "byobcdn-fetch-tasks-queue" {
  binding {
    members = [
      google_service_account.byobcdn-process-runner.member,
    ]
    role = "roles/cloudtasks.enqueuer"
  }
}

resource "google_cloud_tasks_queue_iam_policy" "byobcdn-fetch" {
  name        = google_cloud_tasks_queue.byobcdn-fetch.name
  policy_data = data.google_iam_policy.byobcdn-fetch-tasks-queue.policy_data
}

resource "google_service_account" "byobcdn-process-runner" {
  account_id   = "byobcdn-process-runner"
  display_name = "byobcdn-process-runner"
}

data "google_iam_policy" "byobcdn-process-runner" {}

resource "google_service_account_iam_policy" "byobcdn-process-runner" {
  policy_data        = data.google_iam_policy.byobcdn-process-runner.policy_data
  service_account_id = google_service_account.byobcdn-process-runner.name
}

resource "google_cloudfunctions_function" "byobcdn-process" {
  name                  = "byobcdn-process"
  runtime               = "nodejs18"
  entry_point           = "function"
  available_memory_mb   = 256
  trigger_http          = true
  timeout               = 300
  service_account_email = google_service_account.byobcdn-process-runner.email
  environment_variables = {
    BYOBCDN_FETCH_ENDPOINT = google_cloudfunctions_function.byobcdn-fetch.https_trigger_url
    BYOBCDN_FETCH_INVOKER  = google_service_account.byobcdn-fetch-invoker.email
    BYOBCDN_FETCH_QUEUE    = google_cloud_tasks_queue.byobcdn-fetch.id
  }
  lifecycle {
    ignore_changes = [
      labels["deployment-tool"],
    ]
  }
}

data "google_iam_policy" "byobcdn-process" {
  binding {
    members = [
      google_service_account.byobcdn-process-invoker.member,
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-process" {
  cloud_function = google_cloudfunctions_function.byobcdn-process.name
  policy_data    = data.google_iam_policy.byobcdn-process.policy_data
}

resource "google_cloud_tasks_queue" "byobcdn-process" {
  name     = "byobcdn-process"
  location = "us-central1"
}

data "google_iam_policy" "byobcdn-process-tasks-queue" {
  binding {
    members = [
      google_service_account.byobcdn-watch-runner.member,
    ]
    role = "roles/cloudtasks.enqueuer"
  }
}

resource "google_cloud_tasks_queue_iam_policy" "byobcdn-process" {
  name        = google_cloud_tasks_queue.byobcdn-process.name
  policy_data = data.google_iam_policy.byobcdn-process-tasks-queue.policy_data
}

resource "google_service_account" "byobcdn-process-invoker" {
  account_id   = "byobcdn-process-invoker"
  display_name = "byobcdn-process-invoker"
}

data "google_iam_policy" "byobcdn-process-invoker" {
  binding {
    members = [
      google_service_account.byobcdn-watch-runner.member,
    ]
    role = "roles/iam.serviceAccountUser"
  }
}

resource "google_service_account_iam_policy" "byobcdn-process-invoker" {
  policy_data        = data.google_iam_policy.byobcdn-process-invoker.policy_data
  service_account_id = google_service_account.byobcdn-process-invoker.name
}

resource "google_service_account" "byobcdn-www-runner" {
  account_id   = "byobcdn-www-runner"
  display_name = "byobcdn-www-runner"
}

data "google_iam_policy" "byobcdn-www-runner" {}

resource "google_service_account_iam_policy" "byobcdn-www-runner" {
  policy_data        = data.google_iam_policy.byobcdn-www-runner.policy_data
  service_account_id = google_service_account.byobcdn-www-runner.name
}

resource "google_cloudfunctions_function" "byobcdn-www" {
  name                  = "byobcdn-www"
  runtime               = "nodejs18"
  entry_point           = "function"
  available_memory_mb   = 256
  trigger_http          = true
  service_account_email = google_service_account.byobcdn-www-runner.email
  ingress_settings      = "ALLOW_INTERNAL_AND_GCLB"
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

data "google_iam_policy" "byobcdn-www" {
  binding {
    members = [
      "allUsers",
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "byobcdn-www" {
  cloud_function = google_cloudfunctions_function.byobcdn-www.name
  policy_data    = data.google_iam_policy.byobcdn-www.policy_data
}
