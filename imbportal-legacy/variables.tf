variable "namespace" {

}

variable "app" {
  default     = "imbportal-legacy"
  description = "k8s \"app\" label"
}

variable "db_root_password" {
  description = "Postgres database root password"
}

variable "wwi_target" {
  type        = string
  description = "WWI target"
}

variable "frontend_domains" {
  type        = list(object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  }))
  description = "Domain name(s) the frontend runs under"
}

variable "frontend_image" {
  default     = "uqrcc/ipp:1.1.2"
  type        = string
  description = "ipp docker image"
}

variable "replicas_frontend" {
  default     = 1
  description = "No. frontend replicas"
}

variable "replicas_client" {
  default     = 1
  description = "No. portal-client replicas"
}

variable "client_oauth2" {
  default = {
    provider = {
      wiener = {
        issuer-uri = "https://auth.rcc.uq.edu.au/auth/realms/wiener"
      }
    }

    registration = {
      wiener = {
        client-id     = "microvolution-client"
        client-name   = "wiener"
        client-secret = "00000000-0000-0000-0000-000000000000"
      }
    }
  }

  description = <<EOF
Spring Security oauth2 configuration.
This is the spring.auth.oauth2.client configuration key
EOF
}