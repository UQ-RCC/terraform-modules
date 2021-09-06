##
# Jump box security group.
# * Allows admin networks to SSH
# * ICMP/Egress is handled by the "internal" group in network.tf
##
resource "openstack_networking_secgroup_v2" "jump_whitelist" {
  name                 = "${var.instance_prefix}-jump"
  description          = "${var.instance_prefix} jump whitelist"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "jump_ssh" {
  # Really getting sick of your shit, Terraform...
  for_each = { for net in var.admin_networks: (net.remote) => net }

  description       = "Allow SSH (${each.value.description})"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value.remote
  security_group_id = openstack_networking_secgroup_v2.jump_whitelist.id
}

resource "openstack_networking_port_v2" "jump_port" {
  name           = "${var.instance_prefix}-jump"
  network_id     = openstack_networking_network_v2.k8snet.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.k8snet_common.id,
    openstack_networking_secgroup_v2.jump_whitelist.id,
  ]

  mac_address = format("%02x:%02x:%02x:%02x:%02x:%02x",
    local.mac_hextets[0],
    local.mac_hextets[1],
    local.mac_hextets[2],
    local.mac_hextets[3],
    local.mac_hextets[4],
    2
  )

  fixed_ip {
    ip_address  = format("%d.%d.%d.%d",
      local.ip_octets[0], local.ip_octets[1],
      local.ip_octets[2], 2
    )
    subnet_id   = openstack_networking_subnet_v2.k8snet.id
  }
}

resource "openstack_compute_instance_v2" "jump_node" {
  name              = "${var.instance_prefix}-jump"
  image_id          = var.image
  flavor_name       = var.flavour_jump
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.terraform.name
}

resource "openstack_compute_interface_attach_v2" "jump_port_attach" {
  instance_id = openstack_compute_instance_v2.jump_node.id
  port_id     = openstack_networking_port_v2.jump_port.id
}

resource "openstack_networking_floatingip_v2" "jump_ip" {
  pool        = var.floating_network_name
  port_id     = openstack_networking_port_v2.jump_port.id
  description = "${var.instance_prefix} jump host"
}

resource "openstack_dns_recordset_v2" "jump" {
  zone_id = var.dns_zone
  name    = "${var.instance_prefix}-jump.${var.dns_base}"
  ttl     = 3600
  type    = "A"
  records = [
    openstack_networking_floatingip_v2.jump_ip.address
  ]
}

output "jump_ip" {
  value = openstack_networking_floatingip_v2.jump_ip.address
}
