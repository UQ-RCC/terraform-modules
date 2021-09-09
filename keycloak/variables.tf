variable "namespace" {

}

variable "app" {
  description = "k8s \"app\" label"
}

variable "db_root_password" {
  type        = string
  description = "Postgres root password"
}

variable "keycloak_domain" {

}

variable "keycloak_admin_user" {

}

variable "keycloak_admin_pass" {

}

variable "keycloak_image" {
  # https://registry.hub.docker.com/r/jboss/keycloak
  default     = "jboss/keycloak:15.0.2"
  description = "KeyCloak docker image"
}

variable "keycloak_domains" {
  type        = list(object({
    domain      = string
    issuer_name = string
    issuer_kind = string
  }))
  description = "Domain name(s) Keycloak runs under"
}

variable "replicas" {
  default     = 1
  type        = number
  description = "No. replicas for HA mode"
}

variable "deployments_volume_name" {
  default     = null
  type        = string
  description = "Name of the volume containing deployment JARs"
}

variable "deployments_volume_path" {
  default     = ""
  type        = string
  description = "Path in the volume containing the deployments"
}