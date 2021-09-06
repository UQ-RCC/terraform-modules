variable "namespace" {

}

variable "image" {
  default     = "uqrcc/portal-client:1.0.7"
  description = "portal-client docker image"
}

variable "allowed_cors_patterns" {
  default     = []
  type        = list(string)
  description = "Allowed CORS origin patterns"
}

variable "app" {
  default     = "portal-client"
  description = "k8s \"app\" label"
}

variable "context_path" {
  default     = "/client"
  description = "HTTP context path"
}

variable "db_username" {
  default = "portal_client"
}

variable "db_password" {

}

variable "db_url" {
  default = "jdbc:postgresql://portal-client-db/nimrod-portal"
}

variable "oauth2" {
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

variable "replicas" {
  default = 1
}
