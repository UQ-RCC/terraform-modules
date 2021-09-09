##
# KeyCloak 15.0.2 operator
# They deliberately make this hostile to install. OLM is too opinionated,
# and they refuse to support Helm. Take the manifests straight from the release
# tarball and install them.
##
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.2.0"
    }
  }
}

resource "kubectl_manifest" "crds" {
  for_each = toset([
    "keycloak.org_keycloakbackups_crd.yaml",
    "keycloak.org_keycloakclients_crd.yaml",
    "keycloak.org_keycloakrealms_crd.yaml",
    "keycloak.org_keycloaks_crd.yaml",
    "keycloak.org_keycloakusers_crd.yaml"
  ])

  yaml_body          = file("${path.module}/crds/${each.value}")
  override_namespace = var.namespace
}

resource "kubectl_manifest" "manifests" {
  for_each = toset([
    "role.yaml",
    "role_binding.yaml",
    "service_account.yaml",
    "operator.yaml"
  ])
  depends_on = [kubectl_manifest.crds]

  yaml_body          = file("${path.module}/${each.value}")
  override_namespace = var.namespace
}
