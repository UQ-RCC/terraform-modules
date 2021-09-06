##
# Networking config.
# See https://docs.k0sproject.io/v1.21.0+k0s.0/networking/#needed-open-ports-protocols
##
locals {
  k0s_apiserver_port          = 6443
  k0s_api_port                = 9443
  k0s_konnectivity_agent_port = 8132
  k0s_konnectivity_admin_port = 8133

  k0s_lb_ports = toset([
    tostring(local.k0s_apiserver_port),
    tostring(local.k0s_api_port),
    tostring(local.k0s_konnectivity_agent_port),
    tostring(local.k0s_konnectivity_admin_port),
  ])

  k0s_lb_names = {
    tostring(local.k0s_apiserver_port)          = "apiserver"
    tostring(local.k0s_api_port)                = "k0s api"
    tostring(local.k0s_konnectivity_agent_port) = "konnectivity agent"
    tostring(local.k0s_konnectivity_admin_port) = "konnectivity admin"
  }
}

resource "openstack_networking_network_v2" "k8snet" {
  name           = "${var.instance_prefix}-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "k8snet" {
  name        = "${var.instance_prefix}-subnet"
  network_id  = openstack_networking_network_v2.k8snet.id
  cidr        = var.network_subnet
  ip_version  = 4

  gateway_ip  = local.gateway_ip
  dns_nameservers = var.dns_nameservers

  ##
  # Keep dynamic stuff out of .0.0/24, .1.0/24, and .2.0/24.
  # Looking at you VRRP.
  ##
  allocation_pool {
    start = format("%d.%d.%d.%d",
      local.ip_octets[0], local.ip_octets[1],
      local.ip_octets[2] + 3, 1
    )

    end = format("%d.%d.%d.%d",
      local.ip_octets[0], local.ip_octets[1],
      local.ip_octets[2] + 3, 254
    )
  }
}

##
# Security group common to all nodes
##
resource "openstack_networking_secgroup_v2" "k8snet_common" {
  name                 = "${var.instance_prefix}-common"
  description          = "${var.instance_prefix} common rules"
  delete_default_rules = true
}

# ### TEMPORARY
# resource "openstack_networking_secgroup_rule_v2" "k8snet_common_all_tcp_in" {
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   remote_ip_prefix  = var.network_subnet
#   security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
# }

# ### TEMPORARY
# resource "openstack_networking_secgroup_rule_v2" "k8snet_common_all_udp_in" {
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "udp"
#   remote_ip_prefix  = var.network_subnet
#   security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
# }



resource "openstack_networking_secgroup_rule_v2" "k8snet_common_all_egress" {
  description       = "Allow IPv4 egress"
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_common_icmp_in" {
  description       = "Allow ICMP ingress"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_common_icmp_out" {
  description       = "Allow ICMP egress"
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
}

resource "openstack_networking_secgroup_rule_v2" "k8snet_common_ssh_from_jump" {
  description       = "Allow SSH from Jump"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${openstack_networking_port_v2.jump_port.fixed_ip.0.ip_address}/32"
  security_group_id = openstack_networking_secgroup_v2.k8snet_common.id
}

resource "openstack_networking_router_v2" "k8srouter" {
  name                = "${var.instance_prefix}-router"
  admin_state_up      = true
  external_network_id = var.floating_network_id
}

resource "openstack_networking_port_v2" "k8snet_nat" {
  name = "${var.instance_prefix}-nat-port"
  network_id = openstack_networking_network_v2.k8snet.id
  admin_state_up = true

  mac_address = local.gateway_mac
  fixed_ip {
    ip_address  = local.gateway_ip
    subnet_id   = openstack_networking_subnet_v2.k8snet.id
  }
}

resource "openstack_networking_router_interface_v2" "k8srouterinterface" {
  router_id = openstack_networking_router_v2.k8srouter.id
  port_id   = openstack_networking_port_v2.k8snet_nat.id
}
