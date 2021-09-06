
resource "openstack_networking_port_v2" "worker_ports" {
  count       = var.count_worker
  name        = format("${var.instance_prefix}-worker-port-%02d", count.index + 1)
  network_id  = openstack_networking_network_v2.k8snet.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.k8snet_common.id,
    openstack_networking_secgroup_v2.workers.id,
  ]

  mac_address = format("%02x:%02x:%02x:%02x:%02x:%02x",
    local.mac_hextets[0],
    local.mac_hextets[1],
    local.mac_hextets[2],
    local.mac_hextets[3],
    local.mac_hextets[4] + 2,
    count.index + 1
  )

  fixed_ip {
    ip_address  = format("%d.%d.%d.%d",
      local.ip_octets[0], local.ip_octets[1],
      local.ip_octets[2] + 2, count.index + 1
    )
    subnet_id   = openstack_networking_subnet_v2.k8snet.id
  }
}

resource "openstack_networking_port_v2" "worker_data_ports" {
  count          = var.count_worker
  name           = format("${var.instance_prefix}-worker-data-port-%02d", count.index + 1)
  network_id     = "00691b0f-69c3-444b-85ea-262dd6909052" # qld-data
  admin_state_up = true
}

resource "openstack_compute_instance_v2" "worker_nodes" {
  count             = var.count_worker
  name              = format("${var.instance_prefix}-worker-%02d", count.index + 1)
  image_id          = var.image
  flavor_name       = var.flavour_worker
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.terraform.name
}

resource "openstack_compute_interface_attach_v2" "worker_port_attach" {
  count       = var.count_worker
  instance_id = openstack_compute_instance_v2.worker_nodes[count.index].id
  port_id     = openstack_networking_port_v2.worker_ports[count.index].id
}

resource "openstack_compute_interface_attach_v2" "worker_data_port_attach" {
  # Hack to ensure this is not eth0
  depends_on = [openstack_compute_interface_attach_v2.worker_port_attach]

  count       = var.count_worker
  instance_id = openstack_compute_instance_v2.worker_nodes[count.index].id
  port_id     = openstack_networking_port_v2.worker_data_ports[count.index].id
}

##
# Worker security group
##
resource "openstack_networking_secgroup_v2" "workers" {
  name                 = "${var.instance_prefix}-workers"
  description          = "${var.instance_prefix} worker communication"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_nodeport_tcp" {
  description       = "Allow NodePort traffic (tcp)"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = var.network_subnet
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_nodeport_udp" {
  description       = "Allow NodePort traffic (udp)"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = var.network_subnet
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_vxlan" {
  description       = "Allow VXLAN traffic"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_ip_prefix  = local.worker_subnet
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_kubelet" {
  description       = "Allow Kubelet API access (from control plane)"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_ip_prefix  = local.control_plane_subnet
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

##
# If someone could tell me what ports konnectivity actually needs to work,
# that would be much-appreciated. I *think* this is enough, but I don't like it.
# NB: Keeping old rules for reference.
##
# resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_allow_lb" {
#   description       = "Allow all from internal lb (for konnectivity)"
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   #remote_ip_prefix  = local.control_plane_subnet
#   remote_ip_prefix  = "${local.apiserver_lb_ip}/32"
#   security_group_id = openstack_networking_secgroup_v2.workers.id
# }

# resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_allow_cp" {
#   description       = "Allow all from control plane (for konnectivity)"
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   remote_ip_prefix  = local.control_plane_subnet
#   security_group_id = openstack_networking_secgroup_v2.workers.id
# }

resource "openstack_networking_secgroup_rule_v2" "k8snet_worker_kubelet2" {
  description       = "Allow Kubelet API access (from workers)"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_ip_prefix  = local.worker_subnet
  security_group_id = openstack_networking_secgroup_v2.workers.id
}
