module "resource-server" {
  source    = "../portal-resource-server"

  namespace   = var.namespace
  app         = "resource-server"
  image       = var.rs_image
  endpoints   = file("${path.module}/nimrod.json")
  ca_key      = var.rs_key
  remote_host = var.rs_remote_host
  jwt_config  = var.rs_jwt_config

  allowed_cors_patterns = local.frontend_cors

  replicas = var.replicas_rs
}
