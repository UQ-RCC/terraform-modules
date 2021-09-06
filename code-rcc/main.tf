##
# code.rcc module
#
# Notes:
# * This uses its own load balancer, it can't share the ingress because it needs SSH
#   on the same IP.
# * Certificates are still handled by cert-manager, they're simply mounted
#   into the container at /tls/tls.{crt,key}
# * HTTP requests are redirected to HTTPS
#
# TODO:
# * Make this use minio.rcc when Gitea eventually supports
#   using S3 as a backend for repositories.
# * Network policies, can't really test until Calico
# * When Gitea v1.15 is released (or whenever https://github.com/go-gitea/gitea/pull/5123)
#   is merged, create and configure a realm in KeyCloak to allow SSO.
# * Test restarting on certificate update
##
terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }

    dns = {
      source  = "hashicorp/dns"
      version = ">= 1.3.0"
    }
  }
}

module "gitea-db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.postgres_password
  app_label   = "gitea-db"

  ensure_users = {
    (var.postgres_username) = {
      options = ["NOSUPERUSER", "LOGIN"]
      password = var.postgres_password
    }
  }

  ensure_databases = {
    gitea = { owner = var.postgres_username }
  }
}

resource "kubernetes_network_policy" "gitea-db-network-policy" {
  metadata {
    name      = "gitea-db-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app" = "gitea-db"
      }
    }

    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {
          match_labels = {
            "app" = "gitea"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            "app" = "gitea"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "gitea-data" {
  metadata {
    name      = "gitea-data"
    namespace = var.namespace
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}

locals {
  app_ini = templatefile("${path.module}/app.ini", {
    app_name          = var.app_name
    domain            = var.domain
    root_url          = "https://${var.domain}"
    secret_key        = var.secret_key
    internal_token    = var.internal_token
    #mail_from         = var.mail_from
    #mail_host         = var.mail_host
    #letsencrypt_email = var.letsencrypt_email
    run_user          = "git"
    run_mode          = var.run_mode
    app_data_path     = "/var/lib/gitea/gitea"
    git_data_path     = "/var/lib/gitea/git"
    postgres_username = var.postgres_username
    postgres_password = var.postgres_password
  })
}

resource "kubernetes_secret" "gitea-config" {
  metadata {
    name      = "gitea-config"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    "app.ini" = local.app_ini
  }
}

resource "kubernetes_secret" "gitea-ldap" {
  metadata {
    name      = "gitea-ldap"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    ldap_bind_dn       = var.ldap_bind_dn
    ldap_bind_password = var.ldap_bind_password
  }
}

resource "kubernetes_secret" "gitea-admin" {
  metadata {
    name      = "gitea-admin"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    password = var.admin_pass
  }
}

resource "kubernetes_deployment" "gitea" {
  metadata {
    name      = "gitea"
    namespace = var.namespace
  }

  wait_for_rollout = false

  spec {
    selector {
      match_labels = {
        app = "gitea"
      }
    }

    ##
    # Gitea can't replicate yet
    # Also works because our Cinder volumes can't multi-attach either
    # Also https://github.com/hashicorp/terraform-provider-kubernetes/pull/1255
    ##
    replicas = 1
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "gitea"
        }

        annotations = {
          "checksum/app.ini" = sha256(local.app_ini)
        }
      }
      spec {
        security_context {
          # Built into the container
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
        }

        volume {
          name = "gitea-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.gitea-data.metadata.0.name
          }
        }

        volume {
          name = "gitea-config"
          secret {
            secret_name = kubernetes_secret.gitea-config.metadata[0].name
          }
        }

        volume {
          name = "gitea-tls"
          secret { secret_name = "gitea-certificate" }
        }

        init_container {
          name = "init-gitea"
          image = var.gitea_image
          image_pull_policy = "IfNotPresent"
          command = ["/bin/sh", "-e", "-c", file("${path.module}/init-gitea.sh")]

          env {
            name  = "GITEA_ADMIN_USER"
            value = var.admin_user
          }

          env {
            name  = "GITEA_ADMIN_EMAIL"
            value = var.admin_email
          }

          env {
            name = "GITEA_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.gitea-admin.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "GITEA_LDAP_HOST"
            value = "ad1.cc.uq.edu.au"
          }

          env {
            name  = "GITEA_LDAP_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.gitea-ldap.metadata[0].name
                key  = "ldap_bind_dn"
              }
            }
          }

          env {
            name  = "GITEA_LDAP_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.gitea-ldap.metadata[0].name
                key  = "ldap_bind_password"
              }
            }
          }

          env {
            name  = "GITEA_UQSTAFF_SEARCH_BASE"
            value = var.ldap_uq_staff_search_base
          }

          env {
            name  = "GITEA_UQSTAFF_FILTER"
            value = var.ldap_uq_staff_filter
          }

          env {
            name  = "GITEA_UQNONSTAFF_SEARCH_BASE"
            value = var.ldap_uq_nonstaff_search_base
          }

          env {
            name  = "GITEA_UQNONSTAFF_FILTER"
            value = var.ldap_uq_nonstaff_filter
          }

          volume_mount {
            mount_path = "/etc/gitea"
            name       = "gitea-config"
            read_only  = true
          }

          volume_mount {
            mount_path = "/var/lib/gitea"
            name       = "gitea-data"
            read_only  = false
          }

          security_context {
            read_only_root_filesystem = true
          }
        }

        container {
          # https://hub.docker.com/r/gitea/gitea
          image             = var.gitea_image
          image_pull_policy = "IfNotPresent"
          name              = "gitea"

          # Until https://github.com/go-gitea/gitea/pull/15861 is backported
          command = ["/usr/local/bin/gitea", "-c", "/etc/gitea/app.ini"]

          volume_mount {
            mount_path = "/etc/gitea"
            name       = "gitea-config"
            read_only  = true
          }

          volume_mount {
            mount_path = "/var/lib/gitea"
            name       = "gitea-data"
            read_only  = false
          }

          volume_mount {
            mount_path = "/tls"
            name       = "gitea-tls"
            read_only  = true
          }

          liveness_probe {
            http_get {
              scheme = "HTTPS"
              path   = "/user/login"
              port   = 3443
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "gitea" {
  metadata {
    name      = "gitea"
    namespace = var.namespace
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = var.domain
    }
  }

  wait_for_load_balancer = false

  spec {
    selector = {
      app = "gitea"
    }
    type             = "LoadBalancer"
    session_affinity = "ClientIP"

    port {
      name        = "gitea-http"
      port        = 80
      target_port = 3080
      protocol    = "TCP"
    }

    port {
      name        = "gitea-https"
      port        = 443
      target_port = 3443
      protocol    = "TCP"
    }

    port {
      name        = "gitea-ssh"
      port        = 22
      target_port = 2222
      protocol    = "TCP"
    }
  }
}


resource "kubectl_manifest" "certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata   = {
      name      = "gitea-certificate"
      namespace = var.namespace
    }
    spec = {
      secretName = "gitea-certificate"
      issuerRef = {
        name = var.issuer_name
        kind = var.issuer_kind
      }
      dnsNames = [var.domain]
    }
  })
}
