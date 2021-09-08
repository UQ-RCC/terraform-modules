##
# Legacy IMB portal.
# Just until the new one is properly deployed.
##
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

resource "kubectl_manifest" "frontend_certificates" {
  for_each = {for d in var.frontend_domains: d.domain => d}

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

resource "kubernetes_service" "wwi" {
  metadata {
    name      = "${var.app}-wwi"
    namespace = var.namespace
  }

  spec {
    type          = "ExternalName"
    external_name = var.wwi_target

    port {
      name        = "https"
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }
  }
}

##
# Two ingresses:
# - One handling things normally
# - One handling /wienerbackend using HTTPS as the transport
# - They both share a domain name, so this is fine
# - Note that the external-dns annotation is only on one of them
##
resource "kubernetes_ingress" "wwi" {
  wait_for_load_balancer = false
  metadata {
    name      = "${var.app}-wwi-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
    }
  }

  spec {
    dynamic "rule" {
      for_each = [for d in var.frontend_domains: d.domain]
      content {
        host = rule.value
        http {
          path {
            path = "/wienerbackend"
            backend {
              service_name = kubernetes_service.wwi.metadata.0.name
              service_port = "https"
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = toset([for d in var.frontend_domains: d.domain])
      content {
        hosts = [tls.value]
        secret_name = yamldecode(kubectl_manifest.frontend_certificates[tls.value].yaml_body_parsed).spec.secretName
      }
    }
  }
}


resource "kubernetes_ingress" "ingress" {
  wait_for_load_balancer = false
  metadata {
    name      = "${var.app}-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "external-dns.alpha.kubernetes.io/hostname"    = join(",", [for d in var.frontend_domains: d.domain])
    }
  }

  spec {
    dynamic "rule" {
      for_each = [for d in var.frontend_domains: d.domain]
      content {
        host = rule.value
        http {
          path {
            path = module.portal-client.context_path
            backend {
              service_name = module.portal-client.service_name
              service_port = "http"
            }
          }

          path {
            path = "/"
            backend {
              service_name = kubernetes_service.frontend.metadata.0.name
              service_port = "http"
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = toset([for d in var.frontend_domains: d.domain])
      content {
        hosts = [tls.value]
        secret_name = yamldecode(kubectl_manifest.frontend_certificates[tls.value].yaml_body_parsed).spec.secretName
      }
    }
  }
}
