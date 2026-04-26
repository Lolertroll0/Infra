resource "proxmox_vm_qemu" "HomeAssistantOS" {
  name = "HomeAssistantOS"
  desc = "Main Home Automation Server"
  target_node = "HAOS_VM"
  onboot = true

  clone = var.haosTemplate
  os_type = "cloudinit"
  full_clone = true
  cores = 2
  sockets = 1
  memory = 4096
  
  disk {
    size = "64G"
    storage = "haosstorage"
  }
  network {
    bridge = "br-vm"
    model = "virtio"
  }
}

resource "proxmox_vm_qemu" "ezBookKeeping" {
  name = "ezBookKeeping"
  desc = "EZ Bookkeeping"
  target_node = "EZBK_VM"
  onboot = true
  clone = var.ezbkTemplate
  os_type = "cloudinit"
  full_clone = true
  cores = 2
  sockets = 1
  memory = 2048

  disk {
    size = "64G"
    storage = "financialStorage"
  }
  network {
    bridge = "br-vm"
    model = "virtio"
  }
}
