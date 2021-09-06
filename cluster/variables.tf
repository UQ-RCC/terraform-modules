variable "cluster_name" {
  default     = "k0s-cluster"
  description = "Cluster Name"
  type        = string  
}

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

variable "count_worker" {
  default     = 2
  description = "The number of worker nodes"
  type        = number
}

variable "count_master" {
  default     = 1
  description = "The number of master nodes"
  type        = number
}

variable "flavour_worker" {
  default = "m3.medium"
  type    = string
}

variable "flavour_master" {
  default = "m3.small"
  type    = string
}

variable "flavour_jump" {
  default = "m3.xsmall"
  type    = string
}

variable "floating_network_id" {
  default     = "058b38de-830a-46ab-9d95-7a614cb06f1b" # QRIScloud
  description = <<EOF
Network to allocate floating IPs from. Used for the apiserver load balancer and router.
EOF
}

variable "floating_network_name" {
  default     = "QRIScloud"
  description = "Name of the floating IP pool. Should be the name of the floating_network_id network."
}

variable "dns_nameservers" {
  default = [
    "1.1.1.1",
    "8.8.8.8",
    "8.8.4.4"
  ]
  type = list(string)
}

variable "network_subnet" {
  default     = "10.0.0.0/22"
  description = "network subnet"
  type        = string
}

variable "mac_base" {
  default     = "52:54:00:00:00:00"
  description = "base mac address"
  type        = string
}

variable "apiserver_whitelist" {
  default = []
  description = "Whitelist for the k8s apiserver"
  type = list(object({
    remote      = string
    description = string
  }))
}

variable "admin_networks" {
  description = "Administration network whitelist"
  type = list(object({
    remote      = string
    description = string
  }))
}

variable "dns_zone" {
  description = "Designate DNS Zone UUID"
  type        = string
}

variable "dns_base" {
  description = "Designate DNS Zone FQDN"
  type        = string
}

locals {
  ip_length   = parseint(split("/", var.network_subnet)[1], 10)
  ip_octets   = [for i in split(".", split("/", var.network_subnet)[0]) : parseint(i, 10)]
  mac_hextets = [for i in split(":", var.mac_base) : parseint(i, 16)]

  control_plane_subnet = format("%d.%d.%d.0/24",
    local.ip_octets[0], local.ip_octets[1],
    local.ip_octets[2] + 1
  )

  worker_subnet = format("%d.%d.%d.0/24",
    local.ip_octets[0], local.ip_octets[1],
    local.ip_octets[2] + 2
  )

  dynamic_subnet = format("%d.%d.%d.0/24",
    local.ip_octets[0], local.ip_octets[1],
    local.ip_octets[2] + 3
  )

  gateway_ip  = format("%d.%d.%d.%d",
    local.ip_octets[0], local.ip_octets[1],
    local.ip_octets[2], 1
  )
  gateway_mac = format("%02x:%02x:%02x:%02x:%02x:%02x",
    local.mac_hextets[0],
    local.mac_hextets[1],
    local.mac_hextets[2],
    local.mac_hextets[3],
    local.mac_hextets[4],
    1
  )

  apiserver_lb_ip = format("%d.%d.%d.%d",
    local.ip_octets[0], local.ip_octets[1],
    local.ip_octets[2], 254
  )
  apiserver_lb_mac = format("%02x:%02x:%02x:%02x:%02x:%02x",
    local.mac_hextets[0],
    local.mac_hextets[1],
    local.mac_hextets[2],
    local.mac_hextets[3],
    local.mac_hextets[4],
    254
  )
}
