resource "proxmox_vm_qemu" "HomeAssistantOS" {
  name        = "HomeAssistantOS"
  desc        = "Main Home Automation Server"
  target_node = "HAOS_VM"
  onboot      = true

  clone      = var.haosTemplate
  full_clone = true
  cores      = 2
  sockets    = 1
  memory     = 4096

  disk {
    size    = "64G"
    storage = "haosstorage"
  }
  network {
    bridge = "br-vm"
    model  = "virtio"
  }
}

resource "proxmox_vm_qemu" "ezBookKeeping" {
  name        = "ezBookKeeping"
  desc        = "EZ Bookkeeping"
  target_node = "EZBK_VM"
  onboot      = true
  clone       = var.ezbkTemplate
  full_clone  = true
  cores       = 2
  sockets     = 1
  memory      = 2048

  # --- CLOUD-INIT CONFIGURATION ---
  os_type = "cloudinit"

  # Basic access
  ciuser  = var.adminUser
  sshkeys = file(var.mainKeyPublic)

  # Networking
  ipconfig0 = "ip=dhcp"

  disk {
    size    = "64G"
    storage = "financialStorage"
  }
  network {
    bridge = "br-vm"
    model  = "virtio"
  }
}

# --- DOCKER PROVISIONING ---
# Wait for the VM to boot, then install Docker
resource "null_resource" "setup_ezBookKeeping" {
  depends_on = [proxmox_vm_qemu.ezBookKeeping]

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "curl -sSL https://get.docker.com | sh",
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker ${var.adminUser}",

      # --- TAILSCALE SETUP ---
      "curl -fsSL https://tailscale.com/install.sh | sudo sh",
      "sudo tailscale up --authkey=${var.tailscaleMainAuthKey} --hostname=ezbookkeeping",

      "mkdir -p /home/${var.adminUser}/data/ezbk",
      "sudo docker run --name ezbookkeeping -d -p 8080:8080 -v /home/${var.adminUser}/data/ezbk:/var/lib/ezbk:rw mayswind/ezbookkeeping:latest-snapshot"
    ]

    connection {
      type = "ssh"
      # If using DHCP, Proxmox provider returns the IP in default_ipv4_address
      host        = proxmox_vm_qemu.ezBookKeeping.default_ipv4_address
      user        = var.adminUser
      private_key = file(var.mainKey)
      timeout     = "2m"
    }
  }
}
