resource "openstack_compute_keypair_v2" "terraform" {
  name       = "${var.instance_prefix}-terraform"
  public_key = file(var.ssh_key_file)
}
