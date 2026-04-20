resource "proxmox_vm_qemu" "HomeAssistantOS" {
  name = "HomeAssistantOS"
  desc = "Main Home Automation Server"
  target_node = "HomeAssistantOS"
  onboot = true

  clone = var.proxmox.haosTemplate
  os_type = "cloudinit"
  full_clone = true
  cores = 4
  sockets = 1
  memory = 8192
  
  disk {
    size = "64G"
    storage = "haosstorage"
  }
  network {
    bridge = "br-vm"
    model = "virtio"
  }
}