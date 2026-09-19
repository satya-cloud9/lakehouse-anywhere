terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  # Without a credential source, the provider falls back to hunting for
  # real Application Default Credentials on the host, which don't exist
  # here. access_token skips that search entirely -- it's attached as a
  # bearer token on every request, and since every request goes to
  # floci-gcp via the custom endpoints below rather than to real Google,
  # nothing actually validates it. Reusing the same placeholder string
  # outputs.tf's generated kubeconfig already uses for its own fake token,
  # rather than inventing a second one.
  access_token = "floci-gcp-local"

  # The Google provider validates these against a format regex before ever
  # sending a request -- it has to look like a real GCP endpoint (ends in a
  # path segment plus a trailing slash), not just a bare host:port. Real
  # GCP's own endpoints follow this same shape (container.googleapis.com/v1/,
  # iam.googleapis.com/v1/, storage.googleapis.com/storage/v1/); this
  # mirrors that shape against floci-gcp's single edge port on the guess
  # that it path-routes internally the same way floci/LocalStack does for
  # AWS. UNVERIFIED -- confirm each of these three actually reaches the
  # right emulated service rather than 404ing; if one doesn't, floci-gcp's
  # real routing convention (check its logs) replaces the guess, not the
  # regex-satisfying shape itself.
  container_custom_endpoint = "${var.gcp_emulator_endpoint}/container/"
  iam_custom_endpoint       = "${var.gcp_emulator_endpoint}/"
  storage_custom_endpoint   = "${var.gcp_emulator_endpoint}/storage/v1/"
}
