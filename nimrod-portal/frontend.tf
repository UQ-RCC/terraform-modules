locals {
  frontend_env_js = <<EOF
(function (window) {
    window.__env = window.__env || {};

    window.__env.resourceApiBase = 'https://${var.api_domain.domain}/resource/api/';
    window.__env.serverApiBase   = 'https://${var.api_domain.domain}/nimrod/api/';
    window.__env.base            = '/client/';
    window.__env.apiBase         = '/client/api/';
}(this))
EOF

  frontend_cors = [for d in var.frontend_domains: "https://${d.domain}"]
}

resource "kubernetes_config_map" "frontend_config" {
  metadata {
    name      = "${var.app}-frontend-config"
    namespace = var.namespace
  }

  data = {
    "env.js" = local.frontend_env_js
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "${var.app}-frontend"
    namespace = var.namespace
  }

  wait_for_rollout = false

  spec {
    selector {
      match_labels = {
        app = "${var.app}-frontend"
      }
    }

    # TODO: Autoscaling
    replicas = var.replicas_frontend
    revision_history_limit = 3

    template {
      metadata {
        labels = {
          app = "${var.app}-frontend"
        }

        annotations = {
          "checksum/env.js" = sha256(local.frontend_env_js)
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
          name = "${var.app}-frontend-config"
          config_map {
            name = kubernetes_config_map.frontend_config.metadata[0].name
            items {
              key = "env.js"
              path = "env.js"
            }
          }
        }

        container {
          name              = "frontend"
          image_pull_policy = "Always"
          image             = var.frontend_image

          security_context {
            read_only_root_filesystem = true
          }

          volume_mount {
            name       = "${var.app}-frontend-config"
            mount_path = "/share/nimrod-portal/env.js"
            sub_path   = "env.js"
          }

          resources {
            limits = {
              memory = "10Mi"
              cpu    = "500m"
            }

            requests = {
              memory = "2Mi"
              cpu    = "50m"
            }
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/"
              port   = 8080
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "${var.app}-frontend"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "${var.app}-frontend"
    }
    type             = "NodePort"
    session_affinity = "None"
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
  }
}
