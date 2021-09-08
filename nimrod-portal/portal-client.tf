module "portal-client" {
  source = "../portal-client"

  namespace = "nimrod-portal"

  allowed_cors_patterns = local.frontend_cors
  app                   = "${var.app}-client"
  context_path          = "/client"

  db_username = "portal_client"
  db_password = random_password.client-password.result
  db_url      = "jdbc:postgresql://${module.portal-db.service_name}/portal_client"

  replicas = var.replicas_client

  oauth2 = var.client_oauth2
}
