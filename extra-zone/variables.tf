variable "namespace" {

}

variable "app" {
  description = "k8s \"app\" label"
}

variable "dns_server" {
  description = "rfc2136-supporting DNS server"
}

variable "tsig_key_name" {
  description = "tsig key name. Must match that on the DNS server"
}

variable "acme_endpoint" {
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
  type        = string
  description = "ACME server endpoint"
}

variable "acme_email" {
  type        = string
  description = "ACME email"
}

variable "zone" {
  type = object({
    name          = string
    key_algorithm = string
    key_secret    = string
  })

  default = {
    # NB: Not real credentials
    name          = "domian.example.com"
    key_algorithm = "hmac-sha512"
    key_secret    = "o0ZUJiEH2sUGpQIRiVOb006sNig+wl7U/6e6CpoO1KbZwBvh6VsxQFhJ0ben19q2U3A/i/liSRhKUkJo7c+Fbg=="
  }
}
