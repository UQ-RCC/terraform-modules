variable "acme_endpoint" {
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
  #default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME endpoint"
}

variable "acme_email" {
  description = "ACME account email"
}

variable "dns_server" {
  description = "DNS server for authoritative updates"
}

variable "dns_zone" {
  description = "dns zone for external-dns and cert-manager"
}

variable "dns_tsig_key_name" {
  description = "BIND9 TSIG secret key name"
}

variable "dns_tsig_secret" {
  description = "BIND9 TSIG secret for dynamic updates. Use tsig-keygen."
}

variable "dns_tsig_algorithm" {
  ##
  # NB: This is in the format expected by the "dns" provider. It is transformed
  #     into the required format for cert-manager if required:
  #     upper(replace("hmac-sha256", "-", ""))
  ##
  description = "BIND9 TSIG secret algorithm, e.g. \"hmac-sha256\""
}

variable "kubelet_dir" {
  description = "Kubelet data directory"
  default     = "/var/lib/kubelet"
}

variable "storage_az" {
  description = "Availability Zone for the default storage class"
}

variable "cloud_config" {
  description = "OpenStack cloud.conf contents"
  default = <<EOF
[Global]
application-credential-id     = # openstack application credential create
application-credential-secret = # openstack application credential create
auth-url                      = https://keystone.rc.nectar.org.au:5000/v3/

[Networking]

[LoadBalancer]
availability-zone   = QRIScloud
create-monitor      = true
floating-network-id = 058b38de-830a-46ab-9d95-7a614cb06f1b # QRIScloud
use-octavia         = true

[BlockStorage]

[Metadata]

EOF
}

variable "cluster_name" {
  default     = "kubernetes"
  description = "cluster name passed to OCCM"
}