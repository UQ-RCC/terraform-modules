terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }

  required_version = ">= 0.13"
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

# A role that can access all resources in the namespace
resource "kubernetes_role" "admin" {
  metadata {
    name      = "admin"
    namespace = kubernetes_namespace.namespace.metadata.0.name
  }

  rule {
    api_groups = concat(
      ["", "apps", "autoscaling", "batch", "networking.k8s.io", "rbac.authorization.k8s.io", "cert-manager.io"],
      var.extra_api_groups
    )
    resources  = ["*"]
    verbs      = ["*"]
  }

  # For things that still use extensions/v1beta1
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "admins" {
  metadata {
    name = "admins"
    namespace = kubernetes_namespace.namespace.metadata.0.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.admin.metadata.0.name
  }

  dynamic "subject" {
    for_each = var.admin_users
    content {
      api_group = "rbac.authorization.k8s.io"
      kind      = "User"
      name      = subject.value
    }
  }
}


variable "namespace" {
  description = "Namespace name"
}

variable "admin_users" {
  type        = list(string)
  description = "A list of admin users"
}

variable "extra_api_groups" {
  default = []
  type    = list(string)
}

output "namespace" {
  value = var.namespace
}
