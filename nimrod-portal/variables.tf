variable "namespace" {

}

variable "app" {
  description = "k8s \"app\" label"
}

variable "db_root_password" {
  description = "Postgres database root password"
}

variable "client_image" {
  default     = "uqrcc/portal-client:1.0.8"
  description = "portal-client docker image"
}

variable "rs_image" {
  default     = "uqrcc/portal-resource-server:1.0.12"
  description = "portal-resource-server docker image"
}

variable "frontend_image" {
  default     = "uqrcc/nimrod-portal:1.2.2"
  description = "nimrod-portal frontend docker image"
}

variable "backend_image" {
  default     = "uqrcc/nimrod-portal-backend:1.13.1"
  description = "nimrod-portal-backend docker image"
}

variable "rs_jwt_config" {
  default = {
    audience-id   = "web-client"
    client-id     = "resource-server"
    client-secret = "00000000-0000-0000-0000-000000000000"
    issuer-uri    = "https://auth.rcc.uq.edu.au/auth/realms/hpcportal"
    jwk-set-uri   = "https://auth.rcc.uq.edu.au/auth/realms/hpcportal/protocol/openid-connect/certs"
  }

  description = "portal-resource-server JWT configuration. This is the spring.security.oauth2.resourceserver.jwt.* key"
}

variable "rs_remote_host" {
  description = "portal-resource-server remote ssh host"
}

variable "rs_key" {
  description = "portal-resource-server ssh ca key"
}

variable "api_domain" {
  type = object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  })
  description = "Domain name the backend components run under"
}

variable "frontend_domains" {
  type        = list(object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  }))
  description = "Domain name(s) the frontend runs under"
}

variable "amqp_domain" {
  type = object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  })
  description = "Domain name RabbitMQ runs under"
}

variable "db_domain" {
  type = object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  })
  description = "Domain name Postgres runs under"
}

variable "rabbitmq_clustersize" {
  default = 1
  description = "RabbitMQ cluster size, cannot be decreased later."
}

variable "replicas_frontend" {
  default = 1
}

variable "replicas_rs" {
  default = 1
}

variable "replicas_client" {
  default = 1
}

variable "replicas_backend" {
  default = 1
}

variable "client_oauth2" {
  default = {
    provider = {
      nimrod = {
        issuer-uri = "https://auth.rcc.uq.edu.au/auth/realms/hpcportal"
      }
    }

    registration = {
      nimrod = {
        client-id     = "web-client"
        client-name   = "nimrod"
        client-secret = "00000000-0000-0000-0000-000000000000"
      }
    }
  }

  description = <<EOF
Spring Security oauth2 configuration.
This is the spring.auth.oauth2.client configuration key
EOF
}

variable "master_ca_store" {
  # On Tinaroo, Awoonga, FlashLite, i.e. CentOS 7
  default     = "/etc/ssl/certs/ca-bundle.crt"
  type        = string
  description = "Location of the CA store for the Nimrod Master to use"
}
