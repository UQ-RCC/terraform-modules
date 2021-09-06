##
# Internal load balancer for the apiserver, konnectivity admin/agent, and k9s API port
# - IP is X.X.X.254
##

# resource "openstack_networking_secgroup_v2" "apiserver_internal" {
#   name                 = "${var.instance_prefix}-apiserver-internal"
#   description          = "${var.instance_prefix} apiserver internal"
#   delete_default_rules = true
# }

# resource "openstack_networking_secgroup_rule_v2" "apiserver_internal_icmp_in" {
#   description       = "Allow incoming ICMP"
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "icmp"
#   remote_ip_prefix  = var.network_subnet
#   security_group_id = openstack_networking_secgroup_v2.apiserver_internal.id
# }

# resource "openstack_networking_secgroup_rule_v2" "apiserver_internal_icmp_out" {
#   description       = "Allow outgoing ICMP"
#   direction         = "egress"
#   ethertype         = "IPv4"
#   protocol          = "icmp"
#   remote_ip_prefix  = var.network_subnet
#   security_group_id = openstack_networking_secgroup_v2.apiserver_internal.id
# }

# ##
# # Only allow internal access from workers
# # https://docs.k0sproject.io/v1.21.0+k0s.0/high-availability/
# ##
# resource "openstack_networking_secgroup_rule_v2" "apiserver_internal" {
#   for_each = local.k0s_lb_ports

#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   #remote_ip_prefix  = var.network_subnet
#   remote_ip_prefix  = local.worker_subnet
#   description       = "Allow ${local.k0s_lb_names[each.value]} access"
#   port_range_min    = each.value
#   port_range_max    = each.value

#   security_group_id = openstack_networking_secgroup_v2.apiserver_internal.id
# }

resource "openstack_lb_loadbalancer_v2" "apiserver" {
  name              = "${var.instance_prefix}-apiserver-lb"
  vip_subnet_id     = openstack_networking_subnet_v2.k8snet.id
  vip_address       = local.apiserver_lb_ip
  availability_zone = var.availability_zone
}


resource "openstack_lb_listener_v2" "apiserver" {
  for_each        = local.k0s_lb_ports
  name            = local.k0s_lb_names[each.value]
  protocol        = "TCP"
  protocol_port   = each.value
  loadbalancer_id = openstack_lb_loadbalancer_v2.apiserver.id
  allowed_cidrs   = [
    "${openstack_networking_port_v2.jump_port.fixed_ip.0.ip_address}/32",
    local.dynamic_subnet,
  ]
}

resource "openstack_lb_pool_v2" "apiserver" {
  for_each       = local.k0s_lb_ports
  name           = local.k0s_lb_names[each.value]
  listener_id    = openstack_lb_listener_v2.apiserver[each.value].id
  protocol       = "TCP"
  lb_method      = "ROUND_ROBIN"
  admin_state_up = true
}

resource "openstack_lb_monitor_v2" "apiserver_monitor" {
  pool_id          = openstack_lb_pool_v2.apiserver[local.k0s_apiserver_port].id
  type             = "TCP"
  name             = "apiserver tcp check"
  delay            = 10
  max_retries      = 3
  max_retries_down = 6
  timeout          = 5
}

resource "openstack_lb_members_v2" "masters" {
  for_each = local.k0s_lb_ports

  pool_id  = openstack_lb_pool_v2.apiserver[each.value].id

  dynamic "member" {
    for_each = openstack_networking_port_v2.master_ports
    content {
      address       = member.value.fixed_ip.0.ip_address
      # Why do we need this, isn't this also specified in the listener?
      protocol_port = each.value
      subnet_id     = openstack_networking_subnet_v2.k8snet.id
    }
  }
}
