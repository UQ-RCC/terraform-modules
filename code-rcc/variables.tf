variable "namespace" {
  description = "Kubernetes namespace"
}

variable "app_name" {
  default     = "code.rcc"
  description = "Name of the gitea instance"
}

variable "run_mode" {
  default     = "dev"
  description = "Gitea Run Mode (dev/prod)"
}

variable "secret_key" {
  description = "Gitea INI [security]/SECRET_KEY value"
}

variable "internal_token" {
  description = "Gitea INI [security]/INTERNAL_TOKEN value"
}

variable "admin_user" {
  description = "Initial admin username"
}

variable "admin_pass" {
  description = "Initial admin password"
}

variable "admin_email" {
  description = "Initial admin email address"
}

variable "gitea_image" {
  default     = "gitea/gitea:1.14.2-rootless"
  description = "Gitea docker image, must be the rootless version"
}

variable "init_image" {
  default     = "alpine:3.13.2"
  description = "Docker image used for init containers"
}

variable "ldap_bind_dn" {
  description = "UQ AD Bind DN"
}

variable "ldap_bind_password" {
  description = "UQ AD Bind Password"
}

variable "postgres_username" {
  description = "PostgreSQL Database Username"
}

variable "postgres_password" {
  description = "PostgreSQL Database Password"
}

variable "domain" {
  default     = "code.rcc.uq.edu.au"
  description = "Domain"
}

variable "issuer_name" {
  description = "cert-manager issuer name"
}

variable "issuer_kind" {
  default     = "ClusterIssuer"
  description = "cert-manager issuer kind (Issuer, ClusterIssuer)"
}

variable "ldap_uq_staff_search_base" {
  description = "LDAP search base for staff"
}

variable "ldap_uq_staff_filter" {
  description = "LDAP filter for staff"
}

variable "ldap_uq_nonstaff_search_base" {
  description = "LDAP search base for non-staff"
}

variable "ldap_uq_nonstaff_filter" {
  description = "LDAP filter for non-staff"
}
