##
# Openstack-specific configuration
#
# NB: We're not using the octavia ingress as there's no Helm
#     chart and I cbf doing it manually.
##
resource "kubernetes_secret" "cloud_config" {
  metadata {
    name      = "cloud-config"
    namespace = "kube-system"
  }

  type = "opaque"
  data = {
    "cloud.conf"   = var.cloud_config # For openstack-cloud-controller-manager
    "cloud-config" = var.cloud_config # For cinder-csi-plugin
  }
}

##
# These were taken from https://github.com/kubernetes/cloud-provider-openstack/tree/master/charts/{cinder-csi-plugin,openstack-cloud-controller-manager}
# at revision 2bdbd8a228f551e349e6f81118f75c4a41d7273f. Until their next release.
##

resource "helm_release" "openstack-cloud-controller-manager" {
  name       = "openstack-ccm"
  namespace  = "kube-system"

  #repository = "https://kubernetes.github.io/cloud-provider-openstack"
  #chart      = "openstack-cloud-controller-manager"

  # FIXME: until 1.1.1 is released to fix RBAC issues.
  chart      = "${path.module}/openstack-cloud-controller-manager"

  wait = false

  values = [jsonencode({
    # NB: Embedded YAML list
    controllerExtraArgs = "- --cluster-name=${var.cluster_name}"

    tolerations = [
      {
        key   = "node.cloudprovider.kubernetes.io/uninitialized"
        value = "true"
      },
    #   {
    #     key   = "node-role.kubernetes.io/master",
    #     value = ""
    #   }
    ]

    # nodeSelector = {
    #   "node-role.kubernetes.io/master": ""
    # }

    secret = {
      create = false
      name   = kubernetes_secret.cloud_config.metadata.0.name
    }
  })]
}

resource "helm_release" "cinder-csi-plugin" {
  name      = "cinder-csi-plugin"
  namespace = "kube-system"

  # repository = "https://kubernetes.github.io/cloud-provider-openstack"
  # chart      = "openstack-cinder-csi"

  # Until https://github.com/kubernetes/cloud-provider-openstack/pull/1615 is merged
  chart       = "${path.module}/cinder-csi-plugin"

  wait = false

  values = [jsonencode({
    secret = {
      create  = false
      enabled = true
      name    = kubernetes_secret.cloud_config.metadata.0.name
    }

    csi = {
      nodePlugin = {
        kubeletDir = var.kubelet_dir
      }
    }
  })]
}

##
# Create the default storage class, the defaults don't have the AZ set.
# I could do this in the helm chart, but I prefer it here.
##
resource "kubernetes_storage_class" "standard" {
  metadata {
    name = "standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }

    labels = {
      "kubernetes.io/cluster-service"   = "true"
      "addonmanager.kubernetes.io/mode" = "EnsureExists"
    }
  }
  storage_provisioner    = "cinder.csi.openstack.org"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = "false"
  parameters = {
    availability = var.storage_az
  }
  allowed_topologies {
    match_label_expressions {
      key = "topology.kubernetes.io/zone"
      values = [
        var.storage_az
      ]
    }
  }
}
