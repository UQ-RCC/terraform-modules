##
# External load balancer for the apiserver
# - This is directly has a public address, there's no floating IP attached.
# - Has ${instance_prefix}-api DNS name
#
# Notes:
# - Security groups can't be put on load balancers. Only a list of
#   allowed CIDRs can be put on a listener.
#   - See https://docs.openstack.org/octavia/latest/user/guides/basic-cookbook.html#deploy-a-load-balancer-with-access-control-list
##
resource "openstack_lb_loadbalancer_v2" "apiserver_external" {
  name              = "${var.instance_prefix}-apiserver-external-lb"
  vip_network_id    = var.floating_network_id
  availability_zone = var.availability_zone
}

resource "openstack_lb_listener_v2" "apiserver_external" {
  protocol        = "TCP"
  protocol_port   = local.k0s_apiserver_port
  loadbalancer_id = openstack_lb_loadbalancer_v2.apiserver_external.id

  allowed_cidrs = [
    for net in concat(var.apiserver_whitelist, var.admin_networks) : net.remote
  ]
}

resource "openstack_lb_pool_v2" "apiserver_external" {
  listener_id    = openstack_lb_listener_v2.apiserver_external.id
  protocol       = "TCP"
  lb_method      = "ROUND_ROBIN"
  admin_state_up = true
}

resource "openstack_lb_monitor_v2" "apiserver_external_monitor" {
  pool_id          = openstack_lb_pool_v2.apiserver_external.id
  type             = "TCP"
  name             = "apiserver tcp check"
  delay            = 10
  max_retries      = 3
  max_retries_down = 6
  timeout          = 5
}

resource "openstack_lb_members_v2" "masters_external" {
  pool_id  = openstack_lb_pool_v2.apiserver_external.id

  dynamic "member" {
    for_each = openstack_networking_port_v2.master_ports
    content {
      address       = member.value.fixed_ip.0.ip_address
      protocol_port = local.k0s_apiserver_port
      subnet_id     = openstack_networking_subnet_v2.k8snet.id
    }
  }
}

resource "openstack_dns_recordset_v2" "api" {
  zone_id = var.dns_zone
  name    = "${var.instance_prefix}-api.${var.dns_base}"
  ttl     = 3600
  type    = "A"
  records = [
    openstack_lb_loadbalancer_v2.apiserver_external.vip_address
  ]
}

output "apiserver_lb_external_ip" {
  value = openstack_lb_loadbalancer_v2.apiserver_external.vip_address
}
