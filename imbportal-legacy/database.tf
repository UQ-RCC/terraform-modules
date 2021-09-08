resource "random_password" "client-password" {
  length  = 64
  special = false
}

module "portal-db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.db_root_password
  app_label   = "${var.app}-db"

  ensure_users = {
    portal_client = {
      options  = ["NOSUPERUSER", "LOGIN"]
      password = random_password.client-password.result
    }
  }

  ensure_databases = {
    portal_client = { owner = "portal_client" }
  }
}
