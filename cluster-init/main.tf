##
# Core k8s setup
#
# * Requires v1.21.1 minimum
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

    helm = {
      source  = "hashicorp/helm"
      version = "2.1.2"
    }
  }
}

##
# Deploy the Nginx ingress
##
resource "helm_release" "nginx-ingress" {
  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "kube-system"
  wait        = false

  values = [jsonencode({
    rbac = {
      create = true
    }

    controller = {
      config = {
        proxy-buffer-size = "16k"
      }
    }
  })]
}
