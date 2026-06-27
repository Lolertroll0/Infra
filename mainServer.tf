resource "proxmox_vm_qemu" "HomeAssistantOS" {
  name               = "HomeAssistantOS"
  description        = "Main Home Automation Server"
  target_node        = "mainserver"
  start_at_node_boot = true
  startup            = "order=1"
  clone              = var.haosTemplate
  full_clone         = false
  scsihw             = "virtio-scsi-pci"
  agent              = 1
  bios               = "ovmf"
  machine            = "q35"
  cores              = 2
  sockets            = 1
  memory             = 4096

  os_type    = "cloud-init"
  ciuser     = var.adminUser
  cipassword = var.adminPassword

  # trimspace removes trailing newlines that corrupt Cloud-Init YAML injection
  sshkeys = trimspace(file(var.homeAssistantKeyPublic))

  ipconfig0 = "ip=${var.homeAssistantIP}/24,gw=${var.networkGateway}"

  disk {
    slot    = "scsi0"
    type    = "disk"
    size    = "64G"
    storage = var.proxmoxStorage
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.proxmoxStorage
  }

  efidisk {
    efitype = "4m"
    storage = var.proxmoxStorage
  }

  network {
    id = 0

    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      usbs,
      disk,
      efidisk,
    ]
  }
}





resource "proxmox_vm_qemu" "ezBookKeeping" {
  name               = "ezBookKeeping"
  description        = "EZ Bookkeeping"
  target_node        = "mainserver"
  start_at_node_boot = true
  startup            = "order=2"
  clone              = var.ezbkTemplate
  full_clone         = false
  scsihw             = "virtio-scsi-pci"
  cores              = 2
  sockets            = 1
  memory             = 4096

  agent = 1

  os_type    = "cloud-init"
  ciuser     = var.adminUser
  cipassword = var.adminPassword

  # trimspace removes trailing newlines that corrupt Cloud-Init YAML injection
  sshkeys = trimspace(file(var.otherServicesKeyPublic))

  ipconfig0 = "ip=${var.otherServicesIP}/24,gw=${var.networkGateway}"

  disk {
    slot    = "scsi0"
    type    = "disk"
    size    = "64G"
    storage = var.proxmoxStorage
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.proxmoxStorage
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      disk,
    ]
  }
}

# --- DOCKER PROVISIONING ---
# Wait for the VM to boot, then install Docker and Tailscale
resource "null_resource" "setup_ezBookKeeping" {
  depends_on = [proxmox_vm_qemu.ezBookKeeping]

  triggers = {
    host_ip          = proxmox_vm_qemu.ezBookKeeping.default_ipv4_address
    adminUser        = var.adminUser
    otherServicesKey = var.otherServicesKey
    tailscaleSecret  = var.tailscaleSecret
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo systemctl enable --now serial-getty@ttyS0.service",
      "if command -v docker >/dev/null 2>&1; then echo \"Docker is already installed.\"; else curl -fsSL https://get.docker.com | sh; fi",
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker ${var.adminUser}",
      "if command -v tailscale >/dev/null 2>&1; then echo \"Tailscale is already installed.\"; else curl -fsSL https://tailscale.com/install.sh | sudo sh; fi",
      "sudo tailscale up --authkey=${var.tailscaleMainAuthKey} --ssh",
      "mkdir -p ${local.data_dir}/ezbk"
    ]

    connection {
      type = "ssh"
      # If using DHCP, Proxmox provider returns the IP in default_ipv4_address
      host        = var.otherServicesIP
      user        = var.adminUser
      private_key = file(var.otherServicesKey)
      timeout     = "10m"
    }
  }

  provisioner "remote-exec" { # Provisioner for destroying 
    when = destroy
    inline = [
      "set +e",
      "DEVICE_ID=$(sudo tailscale status --json 2>/dev/null | jq -r '.Self.ID')",
      "if [ -n \"$$DEVICE_ID\" ]; then curl -s -u \"${self.triggers.tailscaleSecret}:\" -X DELETE https://api.tailscale.com/api/v2/device/$$DEVICE_ID; fi",
      "sudo tailscale logout",
      "exit 0"
    ]
    connection {
      type        = "ssh"
      host        = self.triggers.host_ip
      user        = self.triggers.adminUser
      private_key = file(self.triggers.otherServicesKey)
      timeout     = "5m"
    }
  }
}
resource "docker_container" "ezbookkeeping" {
  name       = "ezbookkeeping"
  image      = docker_image.ezbookkeeping.name
  provider   = docker.otherServices
  depends_on = [null_resource.setup_ezBookKeeping]

  restart = "unless-stopped"

  volumes {
    container_path = "/var/lib/ezbk"
    host_path      = "${local.data_dir}/ezbk"
  }
  ports {
    internal = 8080
    external = 8080
  }
}

resource "null_resource" "attach_haos_usb" {
  count      = var.homeAssistantUSB != "" ? 1 : 0
  depends_on = [proxmox_vm_qemu.HomeAssistantOS]

  triggers = {
    vm_id      = proxmox_vm_qemu.HomeAssistantOS.id
    usb_device = var.homeAssistantUSB
  }

  provisioner "remote-exec" {
    inline = [
      "qm set ${proxmox_vm_qemu.HomeAssistantOS.vmid} -usb0 host=${var.homeAssistantUSB}"
    ]

    connection {
      type        = "ssh"
      host        = var.mainServer
      user        = "root"
      private_key = file(var.mainKey)
      timeout     = "5m"
    }
  }
}

