variable "ssh_key_file" {
  default     = "~/.ssh/id_ed25519.pub"
  description = "Path to SSH public key"
  type        = string
}

variable "availability_zone" {
  default     = "QRIScloud"
  description = "OpenStack AZ"
  type        = string
}

variable "instance_prefix" {
  default     = "k8s"
  description = "Prefix appended to all resources"
  type        = string
}

variable "image" {
  default     = "b1b609d1-c284-4853-8e1b-611d8b5d815d" # NeCTAR Ubuntu 20.04 LTS (Focal) amd64
  description = "Image ID for the VMs"
  type        = string
}

variable "flavour" {
  default = "m3.xsmall"
  type    = string
}

variable "admin_networks" {
  description = "Administration network whitelist"
  type = list(object({
    remote      = string
    description = string
  }))
}

variable "dns_nameservers" {
  default = [
    "1.1.1.1",
    "8.8.8.8",
    "8.8.4.4"
  ]
  type = list(string)
}


variable "environments" {
  description = <<EOF
A list of delegated "environments"/"clusters". NS records
with the same name are added to dns_base.
EOF
  type = list(string)
}

variable "dns_ha_name" {
  description = "High-Availability DNS Name"
}

variable "dns_zone" {
  description = "Designate DNS Zone UUID"
  type        = string
}

variable "dns_base" {
  description = "Designate DNS Zone FQDN"
  type        = string
}

variable "network_id" {
  default     = "283e92a3-40dc-482f-bb94-9f4632c0190b" # qld
  description = "ID of the public internet"
}
