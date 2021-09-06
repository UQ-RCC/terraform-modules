resource "openstack_compute_keypair_v2" "terraform" {
  name       = "${var.instance_prefix}-dns-terraform"
  public_key = file(var.ssh_key_file)
}

resource "openstack_networking_secgroup_v2" "secgroup" {
  name                 = "${var.instance_prefix}-dns"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "all_egress" {
  description       = "Allow IPv4 egress"
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_in" {
  description       = "Allow ICMP ingress"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_out" {
  description       = "Allow ICMP egress"
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  # Really getting sick of your shit, Terraform...
  for_each = { for net in var.admin_networks: (net.remote) => net }

  description       = "Allow SSH (${each.value.description})"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value.remote
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "dns_udp" {
  description       = "Allow DNS"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "dns_tcp" {
  description       = "Allow loooong DNS"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}


resource "openstack_networking_port_v2" "port" {
  name           = "${var.instance_prefix}-dns"
  network_id     = var.network_id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.secgroup.id
  ]
}

resource "openstack_compute_instance_v2" "dnsserver" {
  name              = format("${var.instance_prefix}-dns")
  image_id          = var.image
  flavor_name       = var.flavour
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.terraform.name

  network {
    port = openstack_networking_port_v2.port.id
  }
}

resource "openstack_dns_recordset_v2" "dns" {
  zone_id = var.dns_zone
  name    = "${var.dns_ha_name}.${var.dns_base}"
  ttl     = 3600
  type    = "A"
  records = openstack_networking_port_v2.port.all_fixed_ips
}

resource "openstack_dns_recordset_v2" "environments" {
  for_each = toset(var.environments)

  zone_id = var.dns_zone
  name    = "${each.value}.${var.dns_base}"
  ttl     = 3600
  type    = "NS"
  records = [ openstack_dns_recordset_v2.dns.name ]
}

output "ha_name" {
  value = trimsuffix(openstack_dns_recordset_v2.dns.name, ".")
}

output "inventory" {
  value = {
    dnsservers = {
      hosts = {
        # For now, while there's only one server
        (var.dns_ha_name) = {
          ansible_host = openstack_networking_port_v2.port.all_fixed_ips[0]
          host_fqdn    = openstack_dns_recordset_v2.dns.name
        }
      }

      vars = {
        ansible_ssh_user             = "ubuntu"
        ansible_ssh_port             = 22
        ansible_ssh_private_key_file = trimsuffix(var.ssh_key_file, ".pub")
        ansible_ssh_common_args      = "-F /dev/null -oIdentitiesOnly=yes"
      }
    }
  }
}