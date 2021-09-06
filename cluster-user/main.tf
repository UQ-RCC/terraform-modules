terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }

  required_version = ">= 0.13"
}

resource "tls_private_key" "key" {
  algorithm   = var.key_algorithm
  ecdsa_curve = var.ecdsa_curve
  rsa_bits    = var.rsa_bits
}

resource "tls_cert_request" "request" {
  key_algorithm   = tls_private_key.key.algorithm
  private_key_pem = tls_private_key.key.private_key_pem

  subject {
    common_name  = var.username
    organization = var.group
  }
}

resource "kubernetes_certificate_signing_request" "csr" {
  metadata {
    name = var.username
  }

  spec {
    usages = [ "client auth" ]
    request = tls_cert_request.request.cert_request_pem
  }

  auto_approve = true
}

output "kubeconfig" {
  value = {
    apiVersion  = "v1"
    kind        = "Config"
    preferences = {}

    clusters = [{
      name = var.cluster_name
      cluster = {
        certificate-authority-data = base64encode(var.cluster_ca)
        server                     = var.cluster_server
      }
    }]

    contexts = [for ctx in var.contexts: {
      name = ctx.name
      context = {
        cluster   = var.cluster_name
        namespace = ctx.namespace
        user      = var.username
      }
    }]

    current-context = var.contexts[0].name

    users = [{
      name = var.username
      user = {
        client-certificate-data = base64encode(kubernetes_certificate_signing_request.csr.certificate)
        client-key-data         = base64encode(tls_private_key.key.private_key_pem)
      }
    }]
  }
}

output "username" {
  value = var.username
}

# output "uqzvanim_cert" {
#   value = kubernetes_certificate_signing_request.uqzvanim.certificate
# }

# output "uqzvanim_key" {
#   sensitive = true
#   value = tls_private_key.uqzvanim.private_key_pem
# }
# resource "kubernetes_namespace" "code_rcc" {
#   metadata {
#     name = "code-rcc"
#   }

#   provider = kubernetes.dev
# }

# resource "kubernetes_role" "code_rcc_admin" {
#   metadata {
#     name = "admin"
#     namespace = kubernetes_namespace.code_rcc.metadata.0.name
#   }

#   rule {
#     api_groups = [""]
#     resources  = ["*"]
#     verbs      = ["*"]
#   }

#   provider = kubernetes.dev
# }

# resource "kubernetes_role_binding" "code_rcc_admins" {
#   metadata {
#     name = "code-rcc-admins"
#     namespace = kubernetes_namespace.code_rcc.metadata.0.name
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = kubernetes_role.code_rcc_admin.metadata.0.name
#   }

#   subject {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "User"
#     name      = "uqzvanim"
#   }

#   provider = kubernetes.dev
# }
