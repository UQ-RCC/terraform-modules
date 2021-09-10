variable "namespace" {

}

variable "image" {
  default     = "uqrcc/portal-resource-server:1.0.12"
  description = "portal-resource-server docker image"
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

variable "cert_key_bits" {
  default     = 4096
  description = "certificate key bits"
}

variable "cert_validity" {
  default     = 300
  description = "certificate validity length in seconds"
}

variable "remote_host" {
  description = "remote ssh host"
}

variable "ca_key" {
  description = "ssh ca key in PEM format"
}

variable "endpoints" {
  description = "JSON endpoint configuration"
}

variable "allowed_cors_patterns" {
  default     = []
  type        = list(string)
  description = "Allowed CORS origin patterns"
}

variable "app" {
  default     = "portal-resource-server"
  description = "k8s \"app\" label"
}

variable "context_path" {
  default     = "/resource"
  description = "HTTP context path"
}

variable "replicas" {
  default = 1
}
