terraform {
  cloud {
    organization = "wowless-dev"
    workspaces {
      name = "byobcdn"
    }
  }
}

provider "google" {
  project = "www-wowless-dev"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_sourcerepo_repository" "byobcdn" {
  name = "github_wowless_byobcdn"
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
  name                        = "byobcdn.wowless.dev"
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
  available_memory_mb   = 256
  trigger_http          = true
  service_account_email = google_service_account.byobcdn-tact-runner.email
  environment_variables = {}
  labels                = {}
  source_repository {
    url = "https://source.developers.google.com/${google_sourcerepo_repository.byobcdn.id}/moveable-aliases/main/paths/functions/tact"
  }
  timeouts {}
}
