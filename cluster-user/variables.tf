variable "key_algorithm" {
  default = "ECDSA"
}

variable "rsa_bits" {
  default = 4096
}

variable "ecdsa_curve" {
  default = "P521"  
}

variable "username" {
  description = "Principal name, i.e. CN="
}

variable "group" {
  default = ""
  description = "Group name, i.e. O="
}

variable "cluster_name" {
  description = "kubeconfig cluster name"
}

variable "contexts" {
  type = list(object({
    name      = string
    namespace = string
  }))
  description = "kubeconfig contexts. The first is the default."
}

variable "cluster_server" {
  description = "kubeconfig cluster server url"
}

variable "cluster_ca" {
  description = "kubeconfig cluster certificate data (NOT base64'd)"
}
