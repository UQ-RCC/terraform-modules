resource "random_password" "client-password" {
  length  = 64
  special = false
}

resource "random_password" "backend-password" {
  length  = 64
  special = false
}

resource "kubectl_manifest" "db_certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata   = {
      name      = "db-certificate"
      namespace = var.namespace
    }

    spec = {
      secretName = "db-certificate"
      issuerRef = {
        name = var.db_domain.issuer_name
        kind = var.db_domain.issuer_kind
      }
      dnsNames = [ var.db_domain.domain ]
    }
  })
}

module "portal-db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.db_root_password
  app_label   = "${var.app}-db"

  service_type = "LoadBalancer"
  service_annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.db_domain.domain
  }

  tls_enable      = true
  tls_secret_name = "db-certificate"

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
