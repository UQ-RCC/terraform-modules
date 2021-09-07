variable "namespace" {

}

variable "image" {
  default     = "uqrcc/nimrod-portal-backend:1.13.1"
  description = "nimrod-portal-backend docker image"
}

variable "allowed_cors_patterns" {
  default     = []
  type        = list(string)
  description = "Allowed CORS origin patterns"
}

variable "app" {
  default     = "backend"
  description = "k8s \"app\" label"
}

variable "context_path" {
  default     = "/nimrod"
  description = "HTTP context path"
}

variable "db_username" {
  default = "nimrod_portal"
}

variable "db_password" {

}

variable "db_url" {
  default = "jdbc:postgresql://backend-db/nimrod_portal"
}


variable "jwt_config" {
  default = {
    audience-id   = "web-client"
    client-id     = "resource-server"
    client-secret = "00000000-0000-0000-0000-000000000000"
    issuer-uri    = "https://auth.rcc.uq.edu.au/auth/realms/hpcportal"
    jwk-set-uri   = "https://auth.rcc.uq.edu.au/auth/realms/hpcportal/protocol/openid-connect/certs"
  }

  description = "JWT configuration. This is the spring.security.oauth2.resourceserver.jwt.* key"
}

variable "nimrod_config" {
  description = "Nimrod configuration"
}

variable "rabbitmq_secret_name" {
  description = <<EOF
Name of the secret containing the initial password for the RabbitMQ cluster,
created by the RabbitMQ operator.
EOF
}

variable "replicas" {
  default = 1
}