
resource "openstack_networking_port_v2" "master_ports" {
  count       = var.count_master
  name        = format("${var.instance_prefix}-master-port-%02d", count.index + 1)
  network_id  = openstack_networking_network_v2.k8snet.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.k8snet_common.id,
    openstack_networking_secgroup_v2.control_plane.id,
  ]

  mac_address = format("%02x:%02x:%02x:%02x:%02x:%02x",
    local.mac_hextets[0],
    local.mac_hextets[1],
    local.mac_hextets[2],
    local.mac_hextets[3],
    local.mac_hextets[4] + 1,
    count.index + 1
  )

  fixed_ip {
    ip_address  = format("%d.%d.%d.%d",
      local.ip_octets[0], local.ip_octets[1],
      local.ip_octets[2] + 1, count.index + 1
    )
    subnet_id   = openstack_networking_subnet_v2.k8snet.id
  }
}


resource "openstack_compute_instance_v2" "master_nodes" {
  count             = var.count_master
  name              = format("${var.instance_prefix}-master-%02d", count.index + 1)
  image_id          = var.image
  flavor_name       = var.flavour_master
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.terraform.name
}

resource "openstack_compute_interface_attach_v2" "master_port_attach" {
  count       = var.count_master
  instance_id = openstack_compute_instance_v2.master_nodes[count.index].id
  port_id     = openstack_networking_port_v2.master_ports[count.index].id
}

##
# Control Plane security group
##
resource "openstack_networking_secgroup_v2" "control_plane" {
  name                 = "${var.instance_prefix}-control-plane"
  description          = "${var.instance_prefix} control plane communication"
  delete_default_rules = true
}

# etcd<->etcd
resource "openstack_networking_secgroup_rule_v2" "k8snet_controlplane_etcd" {
  description       = "Allow etcd from control plane"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2380
  port_range_max    = 2380
  remote_ip_prefix  = local.control_plane_subnet
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_controlplane" {
  for_each = local.k0s_lb_ports

  description       = "Allow ${local.k0s_lb_names[each.value]}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = var.network_subnet
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}
