locals {
  ssh_private_key_path = trimsuffix(var.ssh_key_file, ".pub")

  ssh_common_args = "-F /dev/null -oIdentitiesOnly=yes -oStrictHostKeyChecking=no"
  ssh_jump_args = "${local.ssh_common_args} -o ProxyCommand=\"ssh ${local.ssh_common_args} -oIdentityFile=${local.ssh_private_key_path} -W %h:%p -q ubuntu@${openstack_networking_floatingip_v2.jump_ip.address}\""

  k8s_bastion_config = {
    address = openstack_networking_floatingip_v2.jump_ip.address
    user    = "ubuntu"
    keyPath = local.ssh_private_key_path
  }
}

output "kubelet_dir" {
  value = "/var/lib/k0s/kubelet"
}

output "k0sctl" {
  value = {
    apiVersion = "k0sctl.k0sproject.io/v1beta1"
    kind = "Cluster"
    metadata = {
      name = var.cluster_name
    }
    spec = {
      hosts = concat([
        for host in openstack_compute_instance_v2.master_nodes:
        {
          ssh = {
            address = host.access_ip_v4
            user = "ubuntu"
            port = 22
            keyPath = trimsuffix(var.ssh_key_file, ".pub")
            bastion = local.k8s_bastion_config
          }
          role = "controller"
          installFlags = [
            "--enable-cloud-provider", "true",
            "--kubelet-extra-args", "--cloud-provider=external"
          ]
        }
      ], [
        for host in openstack_compute_instance_v2.worker_nodes:
        {
          ssh = {
            address = host.access_ip_v4
            user    = "ubuntu"
            port    = 22
            keyPath = trimsuffix(var.ssh_key_file, ".pub")
            bastion = local.k8s_bastion_config
          }
          role = "worker"
          installFlags = [
            "--enable-cloud-provider=true",
            "--kubelet-extra-args", "--node-ip=${host.access_ip_v4}"
          ]
        }
      ])
      # NB: Use "k0s default-config" to see the default and only add changes
      k0s = {
        version = "1.21.2+k0s.0"
        config = {
          apiVersion = "k0s.k0sproject.io/v1beta1"
          kind       = "Cluster"

          spec = {
            telemetry = { enabled = false }

            controllerManager = {
              ##
              # OCCM uses this as a unique identifier for its load balancer names.
              # Without this, LBs in the same tenant will overwrite each other.
              #
              # These are passed to kube-controller-manager as --key=value
              # Won't work until https://github.com/kubernetes/cloud-provider-openstack/issues/1386
              # is fixed though.
              ##
              extraArgs = {
                cluster-name = var.cluster_name
              }
            }

            # https://docs.k0sproject.io/main/high-availability/
            api = {
              port            = local.k0s_apiserver_port
              # The IP of the INTERNAL load balancer, as this is what kubelet talks to
              externalAddress = openstack_lb_loadbalancer_v2.apiserver.vip_address
              sans            = [
                openstack_lb_loadbalancer_v2.apiserver.vip_address,
                openstack_lb_loadbalancer_v2.apiserver_external.vip_address,
                trimsuffix(openstack_dns_recordset_v2.api.name, ".")
              ]
              k0sApiPort      = local.k0s_api_port
            }

            konnectivity = {
              agentPort = local.k0s_konnectivity_agent_port
              adminPort = local.k0s_konnectivity_admin_port
            }

            ##
            # I'd like to use kuberouter, but it doesn't mesh well with
            # Midonet. Calico with VXLAN works a charm.
            ##
            network = {
              podCIDR     = "10.244.0.0/16"
              serviceCIDR = "10.96.0.0/12"
              provider    = "calico"

              calico = {
                mode = "vxlan"
                ipAutodetectionMethod = "cidr=${var.network_subnet}"
              }
            }
          }
        }
      }
    }
  }
}

output "inventory" {
  #sensitive = true
  value = {
    "${var.instance_prefix}_nodes" = {
      hosts = merge({
        for host in openstack_compute_instance_v2.master_nodes:
        host.name => {
          ansible_host = host.access_ip_v4
          ansible_ssh_common_args = local.ssh_jump_args
        }
      }, {
        for host in openstack_compute_instance_v2.worker_nodes:
        host.name => {
          ansible_host = host.access_ip_v4
          ansible_ssh_common_args = local.ssh_jump_args
        }
      }, {
        (openstack_compute_instance_v2.jump_node.name) = {
          ansible_host = openstack_networking_floatingip_v2.jump_ip.address
        }
      })
      vars = {
        ansible_ssh_user             = "ubuntu"
        ansible_ssh_port             = 22
        ansible_ssh_private_key_file = local.ssh_private_key_path
        ansible_ssh_common_args      = local.ssh_common_args
      }
    }

    "${var.instance_prefix}_master_nodes" = {
      hosts = {for host in openstack_compute_instance_v2.master_nodes: host.name => {}}
    }

    "${var.instance_prefix}_worker_nodes" = {
      hosts = {for host in openstack_compute_instance_v2.worker_nodes: host.name => {}}
    }
  }
}
