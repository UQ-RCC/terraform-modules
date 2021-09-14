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

    helm = {
      source  = "hashicorp/helm"
      version = "2.1.2"
    }
  }
}


resource "kubectl_manifest" "xnat_certificates" {
  for_each = {for d in var.xnat_domains: d.domain => d}

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

/* TODO: Use this when https://github.com/Australian-Imaging-Service/charts/issues/56 is fixed
module "db" {
  source = "../postgres"

  namespace   = var.namespace
  volume_size = "1Gi"
  password    = var.db_root_password
  app_label   = "${var.app}-db"

  ensure_users = {
    xnat = {
      options = ["NOSUPERUSER", "LOGIN"]
      password = var.db_root_password
    }
  }

  ensure_databases = {
    xnat = { owner = "xnat" }
  }
}
*/

resource "helm_release" "xnat" {
  name      = "${var.app}-xnat"
  namespace = "ais-xnat"

  repository = "https://australian-imaging-service.github.io/charts"
  chart      = "xnat"
  version    = "0.6.1"

  wait = false

  values = [jsonencode({
    global = {
      postgresql = {
        postgresqlDatabase = "xnat"
        postgresqlUser     = "xnat"
        postgresqlPassword = var.db_root_password
      }
    }

    xnat-web = {
      replicaCount = 1
      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class"                    = "nginx"
          "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
          "external-dns.alpha.kubernetes.io/hostname"      = join(",", [for d in var.xnat_domains: d.domain])
        }

        hosts = [for d in var.xnat_domains: {
          host  = d.domain
          paths = [{path = "/"}]
        }]

        tls = [for d in var.xnat_domains: {
          secretName = yamldecode(kubectl_manifest.xnat_certificates[d.domain].yaml_body_parsed).spec.secretName
          hosts      = [d.domain]
        }]
      }

      timezone = var.timezone

      persistence = {
        cache = {
          accessMode = var.cache_mode
          mountPath  = "/data/xnat/cache"
          size       = var.cache_size
        }
      }

      volumes = {
        archive = {
          accessMode = var.archive_mode
          mountPath  = "/data/xnat/archive"
          size       = var.archive_size
        }
        prearchive = {
          accessMode = var.prearchive_mode
          mountPath  = "/data/xnat/prearchive"
          size       = var.prearchive_size
        }
      }

      plugins = {
        openid-auth-plugin = [{
          name     = "OpenID Authentication Provider"
          provider = { id = "openid" }
          auth     = { method = "openid" }
          auto = {
            enabled = true
            verified = true
          }
          visible                      = true
          disableUsernamePasswordLogin = true
          enabled                      = join(",", [for d in var.xnat_openid: d.name])
          preEstablishedRedirUri       = "/openid-login"
          siteUrl                      = "https://${var.xnat_domain}"
          type                         = "openid"

          openid = {for d in var.xnat_openid: d.name => {
            accessTokenUri      = d.access_token_uri
            userAuthUri         = d.user_auth_uri
            clientId            = d.client_id
            clientSecret        = d.client_secret
            scopes              = join(",", d.scopes)
            allowedEmailDomains = join(",", d.allowed_email_domains)
            link                = d.link
            forceUserCreate     = "true"
            userAutoEnabled     = "true"
            userAutoVerified    = "true"
            emailProperty       = "email"
            givenNameProperty   = "name"
            familyNameProperty  = "deliberately_unknown_property"
          }}
        }]
      }
    }
  })]
}
