terraform {
  required_version = ">= 0.13"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }
}


resource "kubernetes_persistent_volume_claim" "postgres-db-data" {
  metadata {
    name      = "${var.app_label}-data"
    namespace = var.namespace
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.volume_size
      }
    }
  }
}


resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "${var.app_label}-credentials"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    password = var.password
  }
}

resource "kubernetes_secret" "config" {
  metadata {
    name      = "${var.app_label}-config"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    "00-init.sql" = templatefile("${path.module}/00-init.sql.tpl", {
      users     = var.ensure_users
      databases = var.ensure_databases
    })
  }
}

resource "kubernetes_deployment" "postgres-db" {
  metadata {
    name      = var.app_label
    namespace = var.namespace
  }

  wait_for_rollout = false

  spec {
    selector {
      match_labels = {
        app = var.app_label
      }
    }

    replicas = 1
    strategy { type = "Recreate" }

    template {
      metadata {
        name = var.app_label
        labels = {
          app = var.app_label
        }
      }
      spec {
        security_context {
          run_as_user     = 70
          run_as_group    = 70
          run_as_non_root = true
          fs_group        = 70
        }

        container {
          image             = var.image
          image_pull_policy = "IfNotPresent"
          name              = "postgres"

          args = var.tls_enable ? [
            "-c", "ssl=on",
            "-c", "ssl_cert_file=/tls/tls.crt",
            "-c", "ssl_key_file=/tls/tls.key",
          ] : []

          env {
            name  = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_credentials.metadata.0.name
                key  = "password"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "${var.app_label}-db-data"
            read_only  = false
          }

          volume_mount {
            name       = "${var.app_label}-config"
            mount_path = "/docker-entrypoint-initdb.d/00-init.sql"
            sub_path   = "00-init.sql"
            read_only  = true
          }

          dynamic "volume_mount" {
            for_each = var.tls_enable ? [0] : []
            content {
              name       = "${var.app_label}-tls"
              mount_path = "/tls"
              read_only  = true
            }
          }

          liveness_probe {
            exec {
              command = [ "/usr/local/bin/psql", "-U", "postgres", "postgres", "-c", "SELECT 1" ]
            }
            period_seconds = 10
            initial_delay_seconds = 5
          }
        }
        volume {
          name = "${var.app_label}-db-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres-db-data.metadata.0.name
          }
        }

        volume {
          name = "${var.app_label}-config"
          secret {
            secret_name = kubernetes_secret.config.metadata.0.name
          }
        }

        dynamic "volume" {
          for_each = var.tls_enable ? [var.tls_secret_name] : []
          content {
            name = "${var.app_label}-tls"
            secret {
              secret_name  = var.tls_secret_name
              default_mode = "0600"
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "postgres-db" {
  metadata {
    name        = var.app_label
    namespace   = var.namespace
    annotations = var.service_annotations
  }

  spec {
    selector = {
      app = var.app_label
    }

    ##
    # NB: Change this to "None" when running on something that
    #     supports network policies.
    ##
    type = var.service_type
    port {
      port        = 5432
      target_port = 5432
    }
  }
}

output "secret_name" {
  value = kubernetes_secret.postgres_credentials.metadata.0.name
}

output "service_name" {
  value = kubernetes_service.postgres-db.metadata.0.name
}
