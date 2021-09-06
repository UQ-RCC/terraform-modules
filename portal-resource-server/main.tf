terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }
}


locals {
  application_yml = yamlencode({
    server = {
      address = "0.0.0.0"
      port    = 8080
      servlet = { contextPath = var.context_path }
      use-forwarded-headers = true
    }

    management = {
      server   = { port = 9001 }
      endpoint = {
        health = {
          show-details = "always"
          probes       = { enabled = true }
        }
      }
    }

    cors = {
      allowed-origin-patterns = var.allowed_cors_patterns
      max-age = 3600
    }

    spring = {
      security = {
        oauth2 = {
          resourceserver = {
            jwt = var.jwt_config
          }
        }
      }
    }

    resource-server = {
      cert = {
        ca_passphrase = null
        ca_private    = "/config/keyfile.pem"
        key-algorithm = "RSA"
        key-bits      = var.cert_key_bits
        rng-algorithm = "NativePRNGNonBlocking"
        validity      = var.cert_validity
      }
      jsonfile    = "/config/jsonfile.json"
      remote-host = var.remote_host
      tmpdir      = "/tmp"
    }
  })
}

resource "kubernetes_secret" "rs-config" {
  metadata {
    name      = "${var.app}-config"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    "application.yml" = local.application_yml
    "jsonfile.json"   = var.endpoints
    "keyfile.pem"     = var.ca_key
  }
}


resource "kubernetes_deployment" "portal-resource-server" {
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
    revision_history_limit = 3

    template {
      metadata {
        labels = {
          app = var.app
        }

        annotations = {
          "checksum/application.yml" = sha256(local.application_yml)
          "checksum/jsonfile.json"   = sha256(var.endpoints)
          "checksum/keyfile.pem"     = sha256(var.ca_key)
        }
      }

      spec {
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
        }

        volume {
          name = "config"
          secret {
            secret_name = kubernetes_secret.rs-config.metadata[0].name
          }
        }

        volume {
          name = "tmp"
          empty_dir {
            size_limit = "1Mi"
          }
        }

        container {
          name              = "portal-resource-server"
          image_pull_policy = "Always"
          image             = var.image

          volume_mount {
            mount_path = "/config"
            name       = "config"
            read_only  = true
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp"
            read_only  = false
          }

          security_context {
            read_only_root_filesystem = true
          }

          resources {
            limits = {
              memory = "500Mi"
              cpu    = "2000m"
            }
            requests = {
              memory = "250Mi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/actuator/health/liveness"
              port   = 9001
            }
          }

          readiness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/actuator/health/readiness"
              port   = 9001
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "portal-resource-server" {
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

output "service_name" {
  value = kubernetes_service.portal-resource-server.metadata.0.name
}

output "context_path" {
  value = var.context_path
}
