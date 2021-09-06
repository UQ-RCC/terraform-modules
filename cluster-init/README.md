# cluster-init Terraform module

Configure/initialise a k8s cluster created by the `cluster` module.

* This will install the following components:
  * `openstack-cloud-controller-manager`
  * `cinder-csi-plugin`
  * `external-dns`
  * `cert-manager`
  * `nginx-ingress`
* All components are installed into the `kube-system` namespace.
* A Cinder storage class with the name `standard` will be created with
  the provided AZ.
* A `cert-manager` ClusterIssuer with the name `letsencrypt` will be created.

## Components

### openstack-cloud-controller-manager

This will configure the nodes with OpenStack and make them schedulable.
Installed via Helm.

Until the next release, a local copy of the Helm chart is used because
of RBAC issues with k8s 1.21. Chart version 1.1.1 fixes these issues.

### cinder-csi-plugin

This will configure Cinder for volume storage.
Installed via Helm.

Until the next release, a local copy of the Helm chart is used until a
chart is released with https://github.com/kubernetes/cloud-provider-openstack/pull/1615 applied.

### external-dns

This will install `external-dns`, configured to use the DNS server specified by
the `dns_*` input variables. Installed via Helm.

The DNS secrets are shared with `cert-manager`.

### cert-manager

This will install `cert-manager`, configured to use the DNS server specified by
the `dns_*` input variables. Installed via Helm.

The DNS secrets are shared with `external-dns`.

### nginx-ingress

This will install the Nginx ingress, via Helm. Note that we're using this
instead of the native Octavia ingress, as there's no Helm chart for the
Octavia ingress yet.
