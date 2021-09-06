resource "random_password" "client-password" {
  length  = 64
  special = false
}

resource "random_password" "backend-password" {
  length  = 64
  special = false
}

module "portal-db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.db_root_password
  app_label   = "portal-db"

  ensure_users = {
    nimrod_portal = {
      options  = ["NOSUPERUSER", "INHERIT", "CREATEROLE", "CREATEDB", "LOGIN"]
      password = random_password.backend-password.result
    }

    portal_client = {
      options  = ["NOSUPERUSER", "LOGIN"]
      password = random_password.client-password.result
    }
  }

  ensure_databases = {
    nimrod_portal = { owner = "nimrod_portal" }
    portal_client = { owner = "portal_client" }
  }
}
