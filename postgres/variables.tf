variable "namespace" {
  description = "Kubernetes namespace to use"
}

variable "volume_size" {
  description = "Database volume size"
}

variable "password" {
  description = "Database superuser password"
}

variable "image" {
  # https://hub.docker.com/_/postgres
  default     = "postgres:13.1-alpine"
  description = "PostgreSQL docker image"
}

variable "app_label" {
  description = "\"app\" label value"
}

variable "ensure_users" {
  default     = {}
  description = "Ensure these users exist"
}

variable "ensure_databases" {
  default     = {}
  description = "Ensure these databases exist"
}

variable "service_type" {
  default = "ClusterIP"
  type    = string
}

variable "service_annotations" {
  default = {}
  type    = object({})
}
