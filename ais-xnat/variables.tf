variable "namespace" {}

variable "app" {
  description = "k8s \"app\" label"
}

variable "xnat_domains" {
  type        = list(object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  }))
  description = "Domain name(s) XNAT runs under"
}

variable "ctp_domains" {
  type        = list(object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  }))
  description = "Domain name(s) CTP runs under"
}

variable "timezone" {
  default = "Australia/Brisbane"
  type    = string
}

variable "db_root_password" {
  type = string
}

variable "xnat_domain" {
  default     = "xnat.example.com"
  type        = string
  description = "XNAT Site URL"
}

variable "xnat_openid" {
  default     = []
  type        = list(object({
    name                  = string
    access_token_uri      = string
    user_auth_uri         = string
    client_id             = string
    client_secret         = string
    scopes                = list(string)
    allowed_email_domains = list(string)
    link                  = string
  }))
  description = "XNAT OpenID configuration"
}

variable "cache_mode" {
  default     = "ReadWriteOnce"
  type        = string
  description = "Cache volume access mode"
}

variable "cache_size" {
  default     = "10Gi"
  type        = string
  description = "Cache volume size"
}

variable "archive_mode" {
  default     = "ReadWriteOnce"
  type        = string
  description = "Archive volume access mode"
}

variable "archive_size" {
  default     = "50Gi"
  type        = string
  description = "Archive volume size"
}

variable "prearchive_mode" {
  default     = "ReadWriteOnce"
  type        = string
  description = "Prearchive volume access mode"
}

variable "prearchive_size" {
  default     = "50Gi"
  type        = string
  description = "Prearchive volume size"
}
