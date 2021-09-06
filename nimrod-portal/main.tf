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

resource "kubectl_manifest" "portal_api_certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "portal-api-certificate"
      namespace = var.namespace
    }
    spec = {
      secretName = "portal-api-certificate"
      issuerRef  = {
        name = var.api_domain.issuer_name
        kind = var.api_domain.issuer_kind
      }
      dnsNames = [var.api_domain.domain]
    }
  })
}

resource "kubectl_manifest" "frontend_certificates" {
  for_each = {for d in var.frontend_domains: d.domain => d}

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${each.value.domain}-certificate"
      namespace = var.namespace
    }

    spec = {
      secretName = "${each.value.domain}-certificate"
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
    name      = "nimrod-portal-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"               = "nginx"
      "external-dns.alpha.kubernetes.io/hostname" = join(",", concat(
        [var.api_domain.domain], [for d in var.frontend_domains: d.domain]
      ))
    }
  }
  spec {
    rule {
      host = var.api_domain.domain
      http {

        path {
          path = module.resource-server.context_path
          backend {
            service_name = module.resource-server.service_name
            service_port = "http"
          }
        }

        path {
          path = "/nimrod"
          backend {
            service_name = module.backend.service_name
            service_port = "http"
          }
        }
      }
    }

    tls {
      hosts       = [var.api_domain.domain]
      secret_name = yamldecode(kubectl_manifest.portal_api_certificate.yaml_body_parsed).spec.secretName
    }

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
