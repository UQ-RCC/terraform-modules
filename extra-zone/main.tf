##
# Configure cert-manager and external-dns to handle a single DNS zone.
# Usually used for *.example.com when example.com can't be delegated.
#
# TODO:
# - Change the Issuer to a ClusterIssuer and RBAC it.
#   - It's not always desirable for the tenant to be able to access
#     the zone keys...
##
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }

  required_version = ">= 0.13"
}

resource "kubernetes_secret" "update_key" {
  metadata {
    name      = "${var.app}-update-key"
    namespace = var.namespace
  }

  type = "opaque"
  data = {
    "rfc2136_tsig_secret" = var.zone.key_secret
  }
}

resource "kubectl_manifest" "issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind = "Issuer"
    metadata = {
      name      = "${var.app}-issuer"
      namespace = var.namespace
    }
    spec = {
      acme = {
        server = var.acme_endpoint
        email  = var.acme_email
        privateKeySecretRef = { name = "${var.app}-issuer" }
        solvers = [{
          selector = { dnsZones = [var.zone.name] }
          dns01 = {
            rfc2136 = {
              nameserver    = var.dns_server
              tsigKeyName   = var.tsig_key_name
              tsigAlgorithm = upper(replace(var.zone.key_algorithm, "-", ""))
              tsigSecretSecretRef = {
                name = kubernetes_secret.update_key.metadata.0.name
                key  = "rfc2136_tsig_secret"
              }
            }
          }
        }]
      }
    }
  })
}

resource "helm_release" "nimrod-external-dns" {
  name       = "${var.app}-external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  namespace  = var.namespace
  wait       = false
  version    = "5.4.4"

  values = [jsonencode({
    provider = "rfc2136"
    rfc2136 = {
      host          = var.dns_server
      zone          = var.zone.name
      secretName    = kubernetes_secret.update_key.metadata.0.name
      tsigKeyname   = var.tsig_key_name
      tsigSecretAlg = var.zone.key_algorithm
      minTTL        = "3600s"
    }
    domainFilters = [var.zone.name]
  })]
}

output "issuer_name" {
  value = kubectl_manifest.issuer.name
}
