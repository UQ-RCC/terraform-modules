Create a bunch of VMs usable for hosting a k0s cluster.

## Networking

By default it will use a subnet of `10.0.0.0/22` segmented as follows:
* `10.0.0.1` is the external gateway
* `10.0.0.2` is the jump box
* `10.0.0.254` is the apiserver load balancer
* The rest of `10.0.0.0/24` is reserved
* `10.0.1.0/24` is control plane nodes, i.e. `10.0.1.n` is the n'th control plane node
* `10.0.2.0/24` is worker nodes, i.e. `10.0.2.n` is the n'th worker node
* `10.0.3.0/24` is DHCP-controlled space. OpenStack will place load-balancery things here.

MAC addresses start at `52:54:00:00:00:00`, and the final two components match that of the respective
internal IP address, e.g. `52:54:00:00:02:02` is worker 2, with an IP of `10.0.2.2`.

### Firewall

There are four security groups:

* Common - Common to ALL nodes
  - ICMP is allowed globally.
  - Egress is allowed globally.
    - TODO: Reconsider this
  - The Jump box can ssh (on port 22) to ALL nodes
    - Yes, the jump box can ssh to itself, what of it?
* Workers
  - VXLAN traffic (udp 4789) is only allowed between workers
  - NodePort service traffic (tcp/udp 30000-32767) is allowed globally. `¯\_(ツ)_/¯`
  - Kubelet API access (tcp 10250) is allowed from the control plane.
* Control plane
  - etcd traffic (tcp 2380) is allowed between control plane nodes
  - k0s-specified ports are allowed from the entire subnet
    - 6443 - apiserver
    - 9443 - k0s api
    - 8132 - konnectivity agent
    - 8133 - konnectivity admin
* Jump whitelist
  - Allows external ssh to the jump box from admin networks.

### Konnectivity

Konnectivity is uses as kind of a reverse-proxy for scheduler-kubelet
communication. To test if it's working try a `kubectl logs -f` repeatedly.
Sometimes it will error with:
```
kubectl -nkube-system logs -f pod/openstack-cloud-controller-manager-5868m
Error from server: Get "https://10.0.2.2:10250/containerLogs/kube-system/openstack-cloud-controller-manager-5868m/openstack-cloud-controller-manager?follow=true": dial timeout
```

I've had add some rules I *really* don't like to get it working:
* ~~Allow all TCP from the internal LB to the workers~~
* ~~Allow all TCP from the control plane to the workers~~
* Allow Kubelets to talk to each other.

### Load Balancers

There are two load balancers for the cluster. One grants external access to
the Kubernetes Apiserver (port 6443), and the other is for internal access to
the four k0s ports listed above. Both load-balance across all master nodes.

At time of writing, security groups cannot be applied to load balancers; access
restrictions have to be added to each listener instead (see [here](https://docs.openstack.org/octavia/latest/user/guides/basic-cookbook.html#deploy-a-load-balancer-with-access-control-list)).

The external load balancer only allows access from the explicit apiserver whitelist and
admin networks.

The internal load balancer only allows access from the dynamic network range (as that's where
load balancer ports are put) and the jump box.