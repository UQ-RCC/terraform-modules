locals {
  ##
  # rfc2136_tsig_secret is hardcoded in the external-dns chart
  # so use it for cert-manager as well.
  ##
  dns_key_name = "rfc2136_tsig_secret"
}

resource "kubernetes_secret" "dns-update-key" {
  metadata {
    name      = "dns-update-key"
    namespace = "kube-system"
  }

  type = "opaque"
  data = {
    (local.dns_key_name) = var.dns_tsig_secret
  }
}

##
# Install cert-manager and create a ClusterIssuer
##
resource "helm_release" "cert-manager" {
  depends_on = [ helm_release.openstack-cloud-controller-manager ]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "kube-system"
  wait       = true # Needed to create the issuer
  version    = "v1.5.3"

  values = [jsonencode({
    installCRDs = true
  })]
}

resource "kubectl_manifest" "acme_issuer_staging" {
  depends_on = [helm_release.cert-manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = {
      name      = "letsencrypt-staging"
      namespace = "kube-system"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = { name = "letsencrypt-staging" }
        solvers = [{
          selector = {
            dnsZones = [ var.dns_zone ]
          }
          dns01 = {
            rfc2136 = {
              nameserver    = var.dns_server
              tsigKeyName   = var.dns_tsig_key_name
              tsigAlgorithm = upper(replace(var.dns_tsig_algorithm, "-", ""))
              tsigSecretSecretRef = {
                name = kubernetes_secret.dns-update-key.metadata.0.name
                key  = local.dns_key_name
              }
            }
          }
        }]
      }
    }
  })
}

resource "kubectl_manifest" "acme_issuer_prod" {
  depends_on = [helm_release.cert-manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = {
      name      = "letsencrypt-prod"
      namespace = "kube-system"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = { name = "letsencrypt" }
        solvers = [{
          selector = {
            dnsZones = [ var.dns_zone ]
          }
          dns01 = {
            rfc2136 = {
              nameserver    = var.dns_server
              tsigKeyName   = var.dns_tsig_key_name
              tsigAlgorithm = upper(replace(var.dns_tsig_algorithm, "-", ""))
              tsigSecretSecretRef = {
                name = kubernetes_secret.dns-update-key.metadata.0.name
                key  = local.dns_key_name
              }
            }
          }
        }]
      }
    }
  })
}

##
# Install external-dns
##
resource "helm_release" "external-dns" {
  depends_on = [ helm_release.openstack-cloud-controller-manager ]
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  namespace  = "kube-system"
  wait       = false
  version    = "5.4.4"

  values = [jsonencode({
    provider = "rfc2136"
    rfc2136 = {
      host          = var.dns_server
      zone          = var.dns_zone
      secretName    = kubernetes_secret.dns-update-key.metadata.0.name
      tsigKeyname   = var.dns_tsig_key_name
      tsigSecretAlg = var.dns_tsig_algorithm
      minTTL        = "3600s"
    }
    domainFilters = [var.dns_zone]
  })]
}
