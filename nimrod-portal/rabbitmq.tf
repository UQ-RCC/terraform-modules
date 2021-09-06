resource "kubectl_manifest" "rabbitmq_certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata   = {
      name      = "rabbitmq-certificate"
      namespace = var.namespace
    }

    spec = {
      secretName = "rabbitmq-certificate"
      issuerRef = {
        name = var.amqp_domain.issuer_name
        kind = var.amqp_domain.issuer_kind
      }
      dnsNames = [ var.amqp_domain.domain ]
    }
  })
}

resource "kubectl_manifest" "rabbitmq-cluster" {
  yaml_body = yamlencode({
    apiVersion = "rabbitmq.com/v1beta1"
    kind       = "RabbitmqCluster"

    metadata = {
      name      = "rabbitmq"
      namespace = var.namespace
    }

    wait_for_rollout = true

    spec = {
      replicas = var.rabbitmq_clustersize
      service = {
        type = "LoadBalancer"
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = var.amqp_domain.domain
        }
      }
      tls = {
        secretName             = "rabbitmq-certificate"
        disableNonTLSListeners = true
      }
    }
  })
}
