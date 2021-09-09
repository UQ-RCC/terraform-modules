terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }
}

resource "random_password" "db_password" {
  length  = 64
  special = false
}

##
# This needs to be passed as an env var to Keycloak, so
# dump it in a secret so it's not visible.
##
resource "kubernetes_secret" "db_password" {
  metadata {
    name      = "${var.app}-db-password"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    password = random_password.db_password.result
  }
}

module "keycloak-db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.db_root_password
  app_label   = "${var.app}-db"

  ensure_users = {
    keycloak = {
      options = ["NOSUPERUSER", "LOGIN"]
      password = random_password.db_password.result
    }
  }

  ensure_databases = {
    keycloak = { owner = "keycloak" }
  }
}

##
# Configure RBAC so the pods can see each other
##
resource "kubernetes_service_account" "keycloak-kubeping-service-account" {
  metadata {
    name      = "${var.app}-kubeping-service-account"
    namespace = var.namespace
  }
}

resource "kubernetes_role" "keycloak-kubeping-pod-reader" {
  metadata {
    name      = "${var.app}-kubeping-pod-reader"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "keycloak-kubeping-api-access" {
  metadata {
    name      = "${var.app}-kubeping-api-access"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.keycloak-kubeping-pod-reader.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.keycloak-kubeping-service-account.metadata.0.name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "keycloak_admin_credentials" {
  metadata {
    name      = "${var.app}-admin-credentials"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    username = var.keycloak_admin_user
    password = var.keycloak_admin_pass
  }
}

resource "kubernetes_deployment" "keycloak" {
  metadata {
    name      = var.app
    namespace = var.namespace
  }

  wait_for_rollout = false

  spec {
    selector {
      match_labels = {
        app = var.app
      }
    }

    replicas = var.replicas

    template {
      metadata {
        labels = {
          app = var.app
        }
      }

      spec {
        service_account_name = kubernetes_service_account.keycloak-kubeping-service-account.metadata.0.name

        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
        }

        dynamic "volume" {
          for_each = var.deployments_volume_name != null ? [0] : []
          content {
            name = "deployments"
            persistent_volume_claim { claim_name = var.deployments_volume_name }
          }
        }

        container {
          image             = var.keycloak_image
          image_pull_policy = "Always"
          name              = "keycloak"

          dynamic "volume_mount" {
            for_each = var.deployments_volume_name!= null ? [0] : []
            content {
              name       = "deployments"
              mount_path = "/opt/jboss/keycloak/standalone/deployments"
              sub_path   = var.deployments_volume_path
              read_only  = false
            }
          }

          env {
            name  = "DB_VENDOR"
            value = "postgres"
          }

          env {
            name  = "DB_ADDR"
            value = module.keycloak-db.service_name
          }

          env {
            name  = "DB_DATABASE"
            value = "keycloak"
          }

          env {
            name  = "DB_USER"
            value = "keycloak"
          }

          env {
            name  = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_password.metadata.0.name
                key  = "password"
              }
            }
          }

          env {
            name  = "KEYCLOAK_FRONTEND_URL"
            # It is very important this does not have a trailing /
            value = "https://${var.keycloak_domain}/auth"
          }

          env {
            name  = "PROXY_ADDRESS_FORWARDING"
            value = "true"
          }

          env {
            name  = "KEYCLOAK_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_admin_credentials.metadata.0.name
                key  = "username"
              }
            }
          }

          env {
            name  = "KEYCLOAK_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_admin_credentials.metadata.0.name
                key  = "password"
              }
            }
          }

          env {
            name  = "JAVA_OPTS_APPEND"
            value = join(" ", [
              "-Dkeycloak.profile.feature.docker=enabled"
            ])
          }

          ##
          # See https://github.com/jgroups-extras/jgroups-kubernetes
          ##
          env {
            name  = "JGROUPS_DISCOVERY_PROTOCOL"
            value = "kubernetes.KUBE_PING"
          }

          env {
            name  = "JGROUPS_DISCOVERY_PROPERTIES"
            value = "port_range=0,dump_requests=false"
          }

          env {
            name  = "KUBERNETES_NAMESPACE"
            value = var.namespace
          }

          env {
            name  = "KUBERNETES_LABELS"
            value = "app=${var.app}"
          }

          # Don't even try, Keycloak is actively hostile to this
          # security_context {
          #   read_only_root_filesystem = true
          # }

          # Management interface is bound on 127.0.0.1, so can't use http_get
          liveness_probe {
            exec {
              command = ["/usr/bin/curl", "-H", "Accept: application/json", "http://127.0.0.1:9990/health/live"]
            }
            period_seconds        = 20
            initial_delay_seconds = 30
          }

          readiness_probe {
            http_get {
              path = "/auth/realms/master/.well-known/openid-configuration"
              port = 8080
              http_header {
                name  = "Accept"
                value = "application/json"
              }
            }
            period_seconds        = 10
            initial_delay_seconds = 15
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "keycloak" {
  metadata {
    name      = var.app
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.app
    }
    type             = "NodePort"
    session_affinity = "ClientIP"
    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
  }
}


resource "kubectl_manifest" "keycloak_certificates" {
  for_each = {for d in var.keycloak_domains: d.domain => d}

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${var.app}-${each.value.domain}-certificate"
      namespace = var.namespace
    }

    spec = {
      secretName = "${var.app}-${each.value.domain}-certificate"
      issuerRef = {
        name = each.value.issuer_name
        kind = each.value.issuer_kind
      }
      dnsNames = [each.value.domain]
    }
  })
}


resource "kubernetes_ingress" "ingress" {
  wait_for_load_balancer = false
  metadata {
    name      = "${var.app}-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"               = "nginx"
      "external-dns.alpha.kubernetes.io/hostname" = join(",", concat(
        [for d in var.keycloak_domains: d.domain]
      ))
    }
  }
  spec {
    dynamic "rule" {
      for_each = [for d in var.keycloak_domains: d.domain]
      content {
        host = rule.value
        http {
          path {
            path = "/"
            backend {
              service_name = kubernetes_service.keycloak.metadata.0.name
              service_port = "http"
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = toset([for d in var.keycloak_domains: d.domain])
      content {
        hosts = [tls.value]
        secret_name = yamldecode(kubectl_manifest.keycloak_certificates[tls.value].yaml_body_parsed).spec.secretName
      }
    }
  }
}
