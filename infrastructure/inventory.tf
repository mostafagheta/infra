# ---------------------------------------------------------------------------
# Write the Ansible inventory.ini directly from Terraform state.
# This replaces the old inventory module — no extra module directory needed.
# The file is written to the ansible_task root so Ansible picks it up via
# ansible.cfg  (inventory = inventory.ini).
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../ansible/inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/hosts.tpl", {
    bastion_public_ip = module.compute.bastion_public_ip
    master_ip         = var.master_private_ip
    worker_ips        = var.worker_private_ips
    key_name          = var.key_name
  })
}
