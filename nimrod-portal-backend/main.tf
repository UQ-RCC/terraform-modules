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
      datasource = {
        driver   = "org.postgresql.Driver"
        password = var.db_password
        url      = var.db_url
        username = var.db_username
      }

      security = {
        oauth2 = {
          resourceserver = {
            jwt = var.jwt_config
          }
        }
      }
    }

    nimrod = var.nimrod_config
  })
}

resource "kubernetes_secret" "config" {
  metadata {
    name      = "${var.app}-config"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    "application.yml" = local.application_yml
  }
}

resource "kubernetes_deployment" "backend" {
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

    # TODO: autoscaling
    replicas = var.replicas
    revision_history_limit = 3

    template {
      metadata {
        labels = {
          app = var.app
        }

        annotations = {
          "checksum/application.yml" = sha256(local.application_yml)
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
            secret_name = kubernetes_secret.config.metadata.0.name
          }
        }

        volume {
          name = "tmp"
          empty_dir {
            size_limit = "1Mi"
          }
        }

        volume {
          name = "rabbitmq-default-user"
          secret {
            secret_name = var.rabbitmq_secret_name
          }
        }

        init_container {
          name              = "init-db"
          image_pull_policy = "Always"
          image             = var.image

          command = [ "/bin/nimrod-portal-backend", "--spring.config.location=/config/application.yml", "db", "init" ]

          volume_mount {
            mount_path = "/config"
            name       = "config"
            read_only  = true
          }

          security_context {
            read_only_root_filesystem = true
          }
        }

        init_container {
          name              = "init-rmq"
          image_pull_policy = "Always"
          image             = var.image

          command = [
            "/bin/nimrod-portal-backend", "--spring.config.location=/config/application.yml",
            "rmq", "init", "/rmq/username", "/rmq/password"
          ]

          volume_mount {
            mount_path = "/config"
            name       = "config"
            read_only  = true
          }

          volume_mount {
            mount_path = "/rmq"
            name       = "rabbitmq-default-user"
            read_only  = true
          }

          security_context {
            read_only_root_filesystem = true
          }
        }

        container {
          name              = "nimrod-portal-backend"
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

resource "kubernetes_service" "backend" {
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
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
  }
}

output "service_name" {
  value = kubernetes_service.backend.metadata.0.name
}

output "context_path" {
  value = var.context_path
}
